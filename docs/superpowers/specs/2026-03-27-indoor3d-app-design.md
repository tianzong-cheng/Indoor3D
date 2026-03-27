# Indoor3D iOS App Design Specification

**Date:** 2026-03-27
**Project:** Indoor environment 3D reconstruction for navigation
**Scope:** iOS app + server communication API

---

## 1. Overview

### Purpose
An iOS app for contributing to a crowdsourced database of 3D indoor environments. Users record videos of indoor spaces, upload them to a server for reconstruction, and can view/download the resulting 3D reconstructions (.ply files).

### Key Features
- Video recording with AR-based guidance and real-time feedback
- Upload queue with background upload support
- Browse and download publicly available .ply reconstructions
- 3D visualization of downloaded .ply files

### Constraints
- Small-scale usage: 10-30 second videos, .ply files under 50MB
- Internet-accessible server
- No user accounts initially (extensible for future addition)
- Multiple videos may contribute to a single .ply file (mapping handled server-side)

---

## 2. System Architecture

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│                 │  Upload │                 │ Process │                 │
│    iOS App      │ ──────► │   REST Server   │ ──────► │  Reconstruction │
│                 │         │   (FastAPI)     │         │    Pipeline     │
│  - Record video │         │                 │         │   (existing)    │
│  - Upload queue │ ◄────── │ - File storage  │ ◄────── │                 │
│  - View .ply    │  Download│ - PLY catalog  │  .ply   │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘
```

### Components

| Component | Technology | Responsibility |
|-----------|------------|----------------|
| iOS App | Swift, SwiftUI | Video recording, upload queue, .ply visualization |
| REST Server | Python, FastAPI | Video upload handling, .ply catalog, file serving |
| Reconstruction Pipeline | (existing) | Video processing, .ply generation (out of scope) |

### Data Flow
1. App records video with geolocation → stores in local upload queue
2. App uploads video to server → server returns video ID
3. Server processes video internally (reconstruction logic out of scope)
4. App fetches list of available .ply files
5. App downloads and displays .ply in 3D viewer

---

## 3. API Communication Design

### 3.1 Simple Version (No Security)

**Use Case:** Development, testing, trusted network environments

**Base URL:** `http://your-server:8000/api/v1`

#### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/videos` | POST | Upload video with geolocation metadata |
| `/videos` | GET | List uploaded videos (optional, debugging) |
| `/ply-files` | GET | List all available .ply files |
| `/ply-files/{ply_id}` | GET | Download .ply file |

#### Video Upload

**Request:**
```
POST /videos
Content-Type: multipart/form-data

video: <binary file>
latitude: 37.7749
longitude: -122.4194
altitude: 15.0 (optional)
building_name: "Building A" (optional)
floor: 2 (optional)
```

**Response:**
```json
{
  "video_id": "vid_123",
  "status": "uploaded",
  "created_at": "2026-03-27T10:30:00Z"
}
```

#### List PLY Files

**Request:**
```
GET /ply-files
```

**Response:**
```json
{
  "ply_files": [
    {
      "id": "ply_001",
      "filename": "building_a_floor2.ply",
      "file_size_mb": 32,
      "latitude": 37.7749,
      "longitude": -122.4194,
      "building_name": "Building A",
      "floor": 2,
      "created_at": "2026-03-27T10:30:00Z"
    }
  ]
}
```

#### Download PLY File

**Request:**
```
GET /ply-files/ply_001
```

**Response:** Binary .ply file (Content-Type: application/octet-stream)

---

### 3.2 Industrial-Grade Version (With Security)

**Use Case:** Production deployment, internet-accessible server

**Base URL:** `https://your-server.com/api/v1`

#### Security Model

| Aspect | Implementation |
|--------|----------------|
| Transport | HTTPS only (TLS 1.2+) |
| Authentication | API Key per device (register on first launch) |
| Video Upload | Authenticated, rate-limited per device |
| PLY Download | Public access via time-limited signed URLs |
| Input Validation | File type/size limits, malware scanning |

#### Endpoints

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/auth/register` | POST | None | Register device, get API key |
| `/videos` | POST | Required | Upload video with metadata |
| `/videos` | GET | Optional | List videos (admin: all, user: own) |
| `/ply-files` | GET | None | List all .ply files (public) |
| `/ply-files/{ply_id}` | GET | None | Download .ply (signed URL) |

#### Device Registration

**Request:**
```
POST /auth/register
Content-Type: application/json

{
  "device_id": "UUID",
  "device_name": "iPhone 15 Pro"
}
```

**Response:**
```json
{
  "api_key": "sk_live_abc123...",
  "created_at": "2026-03-27T10:30:00Z"
}
```

#### Authenticated Upload

**Request:**
```
POST /videos
Authorization: Bearer sk_live_abc123...
Content-Type: multipart/form-data

video: <binary file>
latitude: 37.7749
longitude: -122.4194
...
```

**Response:**
```json
{
  "video_id": "vid_123",
  "status": "uploaded"
}
```

#### Signed Download URL

**Request:**
```
GET /ply-files/ply_001
```

**Response:**
```json
{
  "download_url": "https://storage.example.com/ply_001?sig=abc&expires=1234567890",
  "expires_at": "2026-03-27T11:30:00Z"
}
```

Or server can redirect directly to signed URL.

---

## 4. iOS App Architecture

### 4.1 Module Structure

```
Indoor3D/
├── App/
│   └── Indoor3DApp.swift              # App entry point
│
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift            # HTTP requests, error handling
│   │   ├── Endpoints.swift            # API endpoint definitions
│   │   └── Models/                    # Request/response Codable models
│   │       ├── VideoUploadRequest.swift
│   │       ├── VideoUploadResponse.swift
│   │       ├── PLYFile.swift
│   │       └── PLYListResponse.swift
│   │
│   ├── Storage/
│   │   ├── VideoStore.swift           # Local video file management
│   │   ├── PLYStore.swift             # Downloaded .ply cache
│   │   └── UploadQueue.swift          # Pending uploads persistence
│   │
│   └── Location/
│       └── LocationManager.swift      # GPS coordinates capture
│
├── Features/
│   ├── Recording/
│   │   ├── RecordingView.swift        # Camera preview + UI
│   │   ├── RecordingViewModel.swift   # Recording logic, state management
│   │   ├── ARGuidanceOverlay.swift    # AR coverage indicators, direction arrows
│   │   └── MotionAnalyzer.swift       # Detect smooth movement, generate prompts
│   │
│   ├── Upload/
│   │   ├── UploadQueueView.swift      # List of pending/completed uploads
│   │   ├── UploadQueueViewModel.swift # Queue management
│   │   └── UploadService.swift        # Background upload handling
│   │
│   └── Gallery/
│       ├── PLYListView.swift          # List available .ply files
│       ├── PLYListViewModel.swift     # Fetch from server
│       └── PLYViewerView.swift        # SceneKit 3D visualization
│
└── Shared/
    ├── Components/                    # Reusable UI components
    └── Extensions/                    # Swift extensions
```

### 4.2 Technology Stack

| Layer | Technology |
|-------|------------|
| UI | SwiftUI |
| Video Capture | AVFoundation |
| AR Guidance | ARKit |
| Motion Detection | CoreMotion |
| Location | CoreLocation |
| Networking | URLSession (background tasks) |
| 3D Visualization | SceneKit |
| Local Storage | FileManager + JSON |

### 4.3 Architecture Pattern

**MVVM (Model-View-ViewModel):**
- **View**: SwiftUI views, declarative UI
- **ViewModel**: ObservableObject, business logic, state management
- **Model**: Codable structs, data persistence

---

## 5. Recording Feature

### 5.1 Screen Layout

```
┌─────────────────────────────────┐
│  ┌─────────────────────────┐ ●  │  ← Recording indicator
│  │                         │    │
│  │    Camera Preview       │    │
│  │    + AR Overlay         │    │
│  │                         │    │
│  │    ┌─────────┐          │    │  ← Coverage grid
│  │    │  Grid   │          │    │
│  │    └─────────┘          │    │
│  │         ↑               │    │  ← Direction arrow
│  │                         │    │
│  └─────────────────────────┘    │
│                                 │
│  ⚠️ Move slower                 │  ← Text prompt
│                                 │
│     [⏸ Pause]  [⏹ Stop]        │
└─────────────────────────────────┘
```

### 5.2 AR Guidance Components

| Component | Description |
|-----------|-------------|
| Coverage grid | Semi-transparent grid showing captured areas |
| Direction arrow | Points toward un-captured areas |
| Movement indicator | Color feedback on speed (green/yellow/red) |
| Floor plane | ARKit-detected floor for grid orientation |

### 5.3 Motion Analysis Prompts

| Motion State | Prompt | Trigger |
|--------------|--------|---------|
| Too fast | "Move slower" | Velocity > threshold |
| Shaky | "Hold steadier" | Rotation rate > threshold |
| Good speed | None | Velocity in optimal range |
| Stopped long | "Keep moving" | No movement 3+ seconds |
| Good coverage | "Great coverage!" | Coverage increases |

### 5.4 Recording Flow

```
1. User taps "Start Recording"
2. ARKit initializes → floor plane detected
3. Recording begins → AR overlay activates
4. MotionAnalyzer provides real-time feedback
5. User taps "Stop" → video saved locally
6. Prompt for optional metadata (building, floor)
7. Video added to upload queue with geolocation
```

### 5.5 Data Captured

| Data | Source |
|------|--------|
| Video file | AVFoundation (MOV/MP4) |
| Latitude/Longitude | CoreLocation |
| Altitude | CoreLocation (optional) |
| Building name | User input (optional) |
| Floor number | User input (optional) |
| Duration | Recording session |

---

## 6. Upload Queue Feature

### 6.1 Upload States

| State | Description | User Actions |
|-------|-------------|--------------|
| Pending | In queue, waiting | None |
| Uploading | Active transfer | Cancel |
| Paused | Waiting for WiFi | Resume |
| Completed | Success | Clear |
| Failed | Error occurred | Retry |

### 6.2 Upload Behavior

- **Background uploads**: URLSession background tasks
- **Retry logic**: Exponential backoff on failure
- **WiFi requirement**: Optional setting for large files
- **Persistence**: Queue survives app restart
- **Progress tracking**: Real-time upload percentage

### 6.3 Upload Queue Screen

```
┌─────────────────────────────────┐
│  Upload Queue              [↻]  │
├─────────────────────────────────┤
│  📹 video_001.mov               │
│  Building A, Floor 2            │
│  ⏳ Uploading... 67%             │
├─────────────────────────────────┤
│  📹 video_002.mov               │
│  Mall, Floor 1                  │
│  ✓ Uploaded                     │
├─────────────────────────────────┤
│  📹 video_003.mov               │
│  No location                    │
│  ⏸ Waiting for WiFi             │
└─────────────────────────────────┘
```

---

## 7. Gallery & 3D Viewer Feature

### 7.1 PLY File States

| State | Available Actions |
|-------|-------------------|
| Not downloaded | Download, View (auto-download) |
| Downloading | Cancel |
| Downloaded | View 3D, Delete local |
| Update available | Re-download |

### 7.2 Gallery Screen

```
┌─────────────────────────────────┐
│  3D Reconstructions        [🔍] │
├─────────────────────────────────┤
│  🏢 Building A - Floor 2        │
│  32 MB • Updated 2h ago         │
│  [Download] [View 3D]           │
├─────────────────────────────────┤
│  🏢 Mall - Floor 1              │
│  45 MB • Updated 1d ago         │
│  [Download] [View 3D]           │
├─────────────────────────────────┤
│  🏢 Library - Floor 1           │
│  28 MB • Downloaded ✓           │
│  [View 3D]                      │
└─────────────────────────────────┘
```

### 7.3 3D Viewer Controls

| Gesture | Action |
|---------|--------|
| Pinch | Zoom in/out |
| Single finger drag | Rotate model |
| Two finger drag | Pan view |
| Double tap | Reset view |
| Button | Share .ply file |

---

## 8. Error Handling

### 8.1 Network Errors

| Error | User Message | Recovery |
|-------|--------------|----------|
| No connection | "No internet connection" | Auto-retry when connected |
| Timeout | "Upload timed out" | Manual retry button |
| Server error | "Server unavailable" | Retry with backoff |
| Invalid response | "Something went wrong" | Log error, show retry |

### 8.2 Recording Errors

| Error | User Message | Recovery |
|-------|--------------|----------|
| Camera unavailable | "Camera not available" | Check permissions |
| Storage full | "Not enough storage" | Free space prompt |
| Location denied | "Location access needed for geotag" | Continue without location |

---

## 9. Future Extensibility

### 9.1 User Accounts (Future)

When adding user accounts:
- Add `/auth/login`, `/auth/signup` endpoints
- Store user session tokens securely in Keychain
- Associate videos with user IDs
- Show user's own uploaded videos separately

### 9.2 Real-time Updates (Future)

For instant reconstruction completion:
- Add WebSocket endpoint `/ws`
- Subscribe to job completion events
- Push notifications when .ply is ready

---

## 10. Implementation Notes

### 10.1 Server Technology Recommendation

**FastAPI (Python)** recommended because:
- Beginner-friendly with excellent documentation
- Automatic OpenAPI/Swagger documentation
- Native async support for concurrent uploads
- Easy integration with Python-based reconstruction pipelines

### 10.2 iOS Minimum Version

**iOS 16.0+** recommended for:
- Modern SwiftUI features
- ARKit improvements
- Better background task handling

### 10.3 Testing Strategy

| Layer | Testing Approach |
|-------|------------------|
| Network | Mock API responses with URLProtocol |
| ViewModels | Unit tests with XCTest |
| UI | XCUITest for critical flows |
| Recording | Manual testing on device |