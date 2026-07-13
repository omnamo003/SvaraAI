# ShivaAI Billing & Subscriptions Specification
**Module 9**  

---

## 1. Billing & Subscription Engine Architecture

The billing module aggregates character-based usage metrics and manages recurring subscriptions.

```
       [FastAPI Web Request]           [Celery Worker (TTS Job Complete)]
                 |                                      |
                 |                                      v
                 |                            [Log Character Usage]
                 v                                      |
     [Validate Active Quota]                            v
                 |                            [Write to DB: usage_records]
                 |                                      |
                 +-----------------+--------------------+
                                   |
                                   v
+---------------------------------------------------------------------------------+
|                                 Pricing Engine                                  |
|                                                                                 |
|                      +----------------------------------+                       |
|                      |    Payment Gateway Abstraction   |                       |
|                      +----------------------------------+                       |
|                                       |                                         |
|                 +---------------------+---------------------+                   |
|                 v                                           v                   |
|   +---------------------------+               +---------------------------+     |
|   |  Stripe Client (Web App)  |               | Adyen Client (Enterprise) |     |
|   +---------------------------+               +---------------------------+     |
+---------------------------------------------------------------------------------+
```

---

## 2. Billing Database Schema

```sql
-- Subscription Plans Definition Table
CREATE TABLE subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL, -- e.g. 'Starter', 'Professional', 'Enterprise'
    tier VARCHAR(50) NOT NULL UNIQUE,
    monthly_price_cents INTEGER NOT NULL,
    base_characters_quota INTEGER NOT NULL, -- Characters included per month
    extra_character_rate_cents NUMERIC(6, 4) NOT NULL, -- Overages rate per character
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Active Organization Subscriptions
CREATE TABLE organization_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'past_due', 'canceled', 'trialing')),
    billing_cycle_anchor TIMESTAMP WITH TIME ZONE NOT NULL,
    stripe_subscription_id VARCHAR(255) UNIQUE,
    current_period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    current_period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_subscription_org ON organization_subscriptions(organization_id);

-- Precise Usage Records (SOC2/Audit compliance)
CREATE TABLE usage_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    job_id UUID REFERENCES jobs(id) ON DELETE SET NULL,
    characters_count INTEGER NOT NULL,
    cost_cents INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_usage_org_cycle ON usage_records(organization_id, created_at);

-- Invoices Table
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    invoice_number VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'open', 'paid', 'uncollectible')),
    subtotal_cents INTEGER NOT NULL,
    tax_cents INTEGER NOT NULL DEFAULT 0,
    discount_cents INTEGER NOT NULL DEFAULT 0,
    total_cents INTEGER NOT NULL,
    pdf_url VARCHAR(512),
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    period_end TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

---

## 3. Usage Calculation & Overages Pricing Engine

The system computes billing periodically using a **sliding invoice logic**:

### Quota Calculation Algorithm
```python
def check_quota_status(organization_id: UUID) -> dict:
    # 1. Fetch current subscription details
    sub = db.query(OrganizationSubscription).filter_by(organization_id=organization_id).first()
    plan = db.query(SubscriptionPlan).filter_by(id=sub.plan_id).first()
    
    # 2. Sum up usage during the current cycle period
    used_chars = db.query(func.sum(UsageRecord.characters_count)).filter(
        UsageRecord.organization_id == organization_id,
        UsageRecord.created_at >= sub.current_period_start,
        UsageRecord.created_at <= sub.current_period_end
    ).scalar() or 0
    
    # 3. Check if base quota is exceeded
    if used_chars < plan.base_characters_quota:
        remaining = plan.base_characters_quota - used_chars
        overage_chars = 0
    else:
        remaining = 0
        overage_chars = used_chars - plan.base_characters_quota
        
    return {
        "used_characters": used_chars,
        "base_quota": plan.base_characters_quota,
        "remaining_base_quota": remaining,
        "overage_characters": overage_chars,
        "overage_cost_cents": int(overage_chars * plan.extra_character_rate_cents)
    }
```

---

## 4. Payment Gateway Abstraction Model

To avoid lock-in with a single gateway (e.g. Stripe), all operations are mapped through an interface:

```python
class PaymentGateway(ABC):
    @abstractmethod
    def create_customer(self, name: str, email: str, org_id: UUID) -> str:
        """Create customer record in payment gateway, return customer ID."""
        pass

    @abstractmethod
    def create_subscription(self, customer_id: str, plan_id: str) -> str:
        """Initialize subscription plan billing profile."""
        pass

    @abstractmethod
    def handle_webhook(self, signature: str, payload: bytes) -> dict:
        """Validate signature and parse events (invoice.paid, etc.)."""
        pass
```
Under this design, implementing a new payment provider (e.g., Adyen or Razorpay) only requires writing a new class implementing the `PaymentGateway` interface. No changes are required in the core business services.
