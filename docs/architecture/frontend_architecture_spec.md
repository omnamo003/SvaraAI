# ShivaAI Frontend Application Architecture
**Document Version**: 1.0.0  
**Status**: APPROVED  
**Date**: July 14, 2026  

---

## 1. Technical Stack & Component Design System

The ShivaAI Web Dashboard is built on **Next.js 14** using the App Router. The client leverages type-safe interfaces and modular rendering structures.

### Main Tech Stack
* **Framework**: Next.js 14 (React 18, TypeScript).
* **Styling**: Tailwind CSS paired with Vanilla CSS custom properties.
* **Component Primitives**: Radix UI (accessible, unstyled primitives) styled with Tailwind CSS via a custom utility function (`cn`).
* **Icons**: Lucide React.
* **Global Client State**: Zustand (lightweight, hook-based state management).
* **Server State & Caching**: SWR (Stale-While-Revalidate) for HTTP API query caching.
* **Audio Visualization**: HTML5 Canvas API (direct visual processing of PCM buffers).

---

## 2. Directory Layout & Folder Organization

The frontend codebase is organized in `/web` as follows:

```
/web
  ├── public/                    # Static assets (logos, fallback audio)
  ├── src/
  │     ├── app/                 # Next.js App Router Pages & Layouts
  │     │     ├── layout.tsx     # Global context wrappers (Theme, Auth, SWR)
  │     │     ├── page.tsx       # Unauthenticated marketing/landing landing page
  │     │     ├── (auth)/        # Auth layouts (Login, Signup, Recovery)
  │     │     └── (dashboard)/   # Authenticated workspace layout
  │     │           ├── page.tsx # Metrics home overview
  │     │           └── studio/  # Interactive Text-to-Speech Studio
  │     ├── components/          # Reusable UI component blocks
  │     │     ├── ui/            # Basic layout pieces (buttons, inputs, dropdowns)
  │     │     ├── dashboard/     # Layout shells (Sidebar, Header, UsageIndicators)
  │     │     └── audio/         # Audio widgets (PlayerTray, WaveformVisualizer)
  │     ├── hooks/               # Custom React hooks (Audio, WebSockets, Auth)
  │     │     ├── useAudioQueue.ts  # Web Audio API binary playback scheduler
  │     │     └── useAuth.ts        # Client login credentials hook
  │     ├── lib/                 # Core client scripts & utility modules
  │     │     ├── api.ts         # Axios client instance with response interceptors
  │     │     └── utils.ts       # Styles string merging helpers
  │     └── types/               # TypeScript namespace definitions (.d.ts)
  ├── tailwind.config.ts         # Design system tokens configuration
  ├── postcss.config.mjs
  └── tsconfig.json              # TypeScript compilation rules
```

---

## 3. Client State Management Strategy

To ensure zero unnecessary re-renders and smooth UI animations, state is strictly partitioned between server cache, local component states, and global stores:

```
                  +----------------------------------------------+
                  |              Next.js Frontend                |
                  +----------------------------------------------+
                                  |
            +---------------------+---------------------+
            |                                           |
            v                                           v
+-----------------------+                   +-----------------------+
|  Server Cache (SWR)   |                   | Global Client Store   |
|                       |                   |       (Zustand)       |
|  - Cloned Voices      |                   |                       |
|  - Usage Statistics   |                   |  - Sidebar Toggle     |
|  - Billing Credits    |                   |  - Dark/Light Theme   |
|  - Generation History |                   |  - Active Audio track |
+-----------------------+                   +-----------------------+
```

### Global Zustand Audio Player Store (`/src/lib/store/useAudioStore.ts`)
Controls the persistent audio player tray. Any component in the app can trigger playback by calling this store's actions:
```typescript
interface AudioState {
  currentTrackId: string | null;
  isPlaying: boolean;
  volume: number; // 0.0 to 1.0
  playbackRate: number; // 0.5 to 2.0
  audioUrl: string | null;
  
  // Actions
  playTrack: (trackId: string, url: string) => void;
  pauseTrack: () => void;
  setVolume: (val: number) => void;
  setRate: (val: number) => void;
  resetPlayer: () => void;
}
```

---

## 4. WebSocket Audio Streaming Hook (Web Audio API)

Real-time speech synthesis streams raw binary PCM data packets to the client. We implement a custom playback scheduler (`useAudioQueue.ts`) utilizing the **Web Audio API** to schedule and play chunks smoothly with sub-100ms latency.

```
                   FastAPI Gateway (WebSocket)
                                |
                                v [Binary ArrayBuffer: PCM audio chunk]
                      +-------------------+
                      |   React Client    |
                      +-------------------+
                                |
                                v (Add to ArrayBuffer queue)
                      +-------------------+
                      |   Audio Context   |
                      +-------------------+
                                |
                                v (Schedule consecutive start times)
                      +-------------------+
                      |   Output Device   |
                      +-------------------+
```

### Playback Queue Scheduler Blueprint
```typescript
import { useRef, useState } from "react";

export function useAudioQueue() {
  const audioCtxRef = useRef<AudioContext | null>(null);
  const nextStartTimeRef = useRef<number>(0);
  const [isProcessing, setIsProcessing] = useState(false);

  const initAudio = () => {
    if (!audioCtxRef.current) {
      audioCtxRef.current = new (window.AudioContext || (window as any).webkitAudioContext)({
        sampleRate: 24000 // XTTS v2 target sample rate
      });
      nextStartTimeRef.current = audioCtxRef.current.currentTime;
    }
  };

  const enqueueChunk = async (arrayBuffer: ArrayBuffer) => {
    initAudio();
    const ctx = audioCtxRef.current!;
    
    // 1. Decode raw PCM array bytes to AudioBuffer
    const audioBuffer = await ctx.decodeAudioData(arrayBuffer);
    
    // 2. Schedule source playback
    const sourceNode = ctx.createBufferSource();
    sourceNode.buffer = audioBuffer;
    sourceNode.connect(ctx.destination);
    
    // Ensure back-to-back seamless audio scheduling
    const startTime = Math.max(nextStartTimeRef.current, ctx.currentTime);
    sourceNode.start(startTime);
    
    // Update next scheduled start time offset
    nextStartTimeRef.current = startTime + audioBuffer.duration;
  };

  return { enqueueChunk, initAudio };
}
```

---

## 5. Session Lifecycle & Authentication Middleware

FastAPI access tokens expire after 15 minutes. To prevent user disruption, we implement a **Silent Token Refresh** loop using Axios request/response interceptors.

```
       Axios Request
             |
             v
[Is Access Token Expired?]
       /           \
     YES            NO
     /               \
    v                 v
[POST /auth/refresh]  [Send Request]
(Reads HttpOnly Cookie)
    |
    v (Success, New JWT)
[Save new Access Token]
    |
    v
[Retry original Request]
```

### Route Protection Middleware (`/src/middleware.ts`)
Next.js Edge Middleware intercepts client requests to `/dashboard/*` to verify authentication states locally:
1. Check if the client holds a session cookie or local JWT token.
2. If token verification fails (or is missing), redirect user instantly to `/login?callbackUrl=/dashboard`.
3. Ensures unauthenticated pages never expose workspace layout layouts.

---

## 6. Layout Hierarchies & Responsive Design

### Dashboard Persistent Workspace Layout
We design a **two-column layout Grid** that adapts fluidly across mobile, tablet, and desktop viewports:

```
+-------------------------------------------------------------+
| Header Bar (Notification Bell | Credit Indicator | Profile) |
+-------------------------------------------------------------+
| Sidebar (Desktop) | Page Content Canvas                     |
|                   | - Voice Studio                          |
| - Home            | - Voice Inventory Grid                  |
| - Studio          | - History Tables                        |
| - Settings        |                                         |
+-------------------+-----------------------------------------+
| Bottom Navigation | Persistent Player Tray (App-wide)       |
| (Mobile viewports)|                                         |
+-------------------------------------------------------------+
```

* **Mobile Adaptability**: The left navigation sidebar transitions to a bottom navigation bar on screens `< 768px`.
* **Docked Audio Player**: Positioned at the bottom of the screen with `z-index: 50`. It uses a blur-backdrop overlay style (`backdrop-filter: blur(12px)`) to visually blend with background dashboard elements.
* **Component Micro-interactions**: Buttons, select dropdown states, and list elements enforce a standard scale transition on hover (`transition: all 0.2s ease-in-out; transform: scale(1.02);`).
