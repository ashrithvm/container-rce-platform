# Containerized Remote Code Execution (RCE) Platform

This is a full-stack web application that allows users to write, submit, and execute code in multiple languages (C++, Java, Python, JavaScript) securely in isolated Docker containers. The application features a modern code editor, real-time job status updates, syntax validation, and robust error handling.

## Features

-   **Multi-language Support:** Execute code in C++, Java, Python, and JavaScript.
-   **Secure Sandboxing:** Code is executed in isolated Docker containers with resource limits (memory, CPU), disabled networking, and a seccomp profile for enhanced security on Linux.
-   **Modern Code Editor:** Uses Monaco Editor (the engine behind VS Code) for a rich editing experience.
-   **Asynchronous Job Queue:** Leverages Bull and Redis to manage code execution jobs, ensuring scalability and reliability.
-   **Real-time Status Updates:** The frontend polls the server to provide real-time feedback on job status (pending, active, completed, or failed).
-   **Pre-execution Syntax Validation:** Code is validated for syntax errors before being sent for execution, providing instant feedback to the user.
-   **Comprehensive Error Handling:** Clear and informative error messages for syntax errors, runtime errors, and timeouts.
-   **Optional Logging:** Execution details can be logged to a MongoDB database.

## Project Structure

```
container-rce-platform/
├── public/              # Static assets for the React frontend
├── src/                 # React frontend source code
│   ├── Pages/
│   └── utils/
├── server/              # Node.js/Express backend
│   ├── config/          # Configuration for database and languages
│   ├── controllers/     # Request handlers for API endpoints
│   ├── docker/          # Docker-related utilities and security profiles
│   ├── routes/          # API routes
│   └── utils/           # Helper utilities for the backend
├── package.json         # Frontend dependencies and scripts
├── server/package.json  # Backend dependencies and scripts
└── README.md
```

## Tech Stack

-   **Frontend:** React, Tailwind CSS, Monaco Editor, Axios
-   **Backend:** Node.js, Express.js
-   **Job Queue:** Bull, Redis
-   **Containerization:** Docker, Dockerode
-   **Database:** MongoDB (optional, for logging)

## Architecture and Design

### High-Level Architecture

The application is designed as a classic client-server architecture with a decoupled, asynchronous backend for processing code execution jobs.

```
┌─────────────────────────────────────────────────────────────────┐
│                          User's Browser                         │
│  ┌─────────────────┐                                            │
│  │  React Frontend │                                            │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Backend Server (Node.js/Express)             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │ API Server  │  │ Job Queue   │  │    Job      │              │
│  │             │  │   (Bull)    │  │ Processor   │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Infrastructure                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │    Redis    │  │   Docker    │  │   Docker    │              │
│  │             │  │   Engine    │  │ Container   │              │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

### Workflow Explained

1.  **Code Submission:** The user writes code in the React frontend and submits it. The frontend sends a `POST` request to the backend API with the code and selected language.
2.  **Job Creation:** The Express server receives the request. Instead of executing the code directly, it creates a new job and adds it to a **job queue** managed by Bull. This queue is backed by Redis. The server immediately returns a `jobId` to the frontend.
3.  **Frontend Polling:** The frontend receives the `jobId` and begins periodically polling a status endpoint (`/api/v1/job-status/:jobId`) to ask for updates.
4.  **Job Processing:** A separate process (the job processor) listens for new jobs on the queue. When it picks up a job, it performs the following steps:
    *   **Syntax Validation:** It first validates the code's syntax to catch simple errors without needing to spin up a container.
    *   **Docker Execution:** If the syntax is valid, it creates a temporary file with the user's code and spins up a new, isolated Docker container. The code is executed within this container.
5.  **Execution and Cleanup:** The container runs the code and captures its `stdout` and `stderr`. After execution completes (or times out), the container is destroyed, and the temporary file is deleted.
6.  **Status Update:** The job processor updates the job's status in Redis with the result (output or error).
7.  **Result Retrieval:** On the next polling request, the frontend receives the `completed` or `failed` status along with the execution result or error message, which is then displayed to the user.

### Design Choices

-   **Asynchronous Job Queue (Bull + Redis):** Direct, synchronous execution of code on the API server would block the request thread, making the server unresponsive and unable to handle other requests. A job queue decouples the long-running execution task from the initial API request, ensuring the server remains available and can scale to handle many concurrent submissions.

-   **Docker for Sandboxing:** Security is the primary concern when running arbitrary code. Docker provides a strong, lightweight isolation mechanism. Each job runs in its own container with a separate filesystem, restricted resources (CPU/memory), and disabled networking, preventing malicious or poorly written code from impacting the host system.

-   **Frontend Polling vs. WebSockets:** While WebSockets would provide true real-time updates, they add complexity to both the frontend and backend (managing connections, scaling, etc.). For this application, polling is a simpler and more robust solution that provides a "good enough" real-time feel without the added overhead.

-   **Pre-execution Syntax Validation:** Running code in a Docker container has a startup cost. By performing a quick syntax check before creating a container, the system can provide immediate feedback for simple errors and save resources by not spinning up containers for code that is guaranteed to fail.

## Prerequisites

-   **Node.js** (v16+ recommended)
-   **npm** (v8+ recommended)
-   **Docker:** Required for code execution. Ensure the Docker daemon is running.
-   **Redis:** Required for the job queue. Can be run locally or via Docker.
-   **MongoDB:** Optional, for logging execution data.

## Quick Start

### 1. Clone the Repository

```sh
git clone https://github.com/your-username/container-rce-platform.git
cd container-rce-platform
```

### 2. Install Dependencies

Install dependencies for both the frontend and backend.

```sh
# Install frontend dependencies
npm install

# Install backend dependencies
cd server
npm install
cd ..
```

### 3. Configure Environment Variables

Create a `.env` file in the `server/` directory. This file is required for connecting to Redis and optionally MongoDB.

```env
# Example .env file in server/

# URL for your Redis instance
REDIS_URL=redis://127.0.0.1:6379

# (Optional) MongoDB connection string for logging
MONGO_URI=mongodb://localhost:27017/rce

# Port for the backend server
PORT=5000
```

> **Note:** If you use the `docker-compose.yml` file provided in the `server` directory, the Redis service will be created for you.

### 4. Start Required Services

Ensure Docker and Redis are running. If you are using the provided Docker Compose setup for Redis:

```sh
cd server
docker-compose up -d redis # Start Redis in detached mode
```

### 5. Run the Application

From the root directory of the project, run the `dev` script:

```sh
npm run dev
```

This command concurrently starts:
-   The **React frontend** on `http://localhost:3000`.
-   The **Express backend** on `http://localhost:5000`.

The frontend is configured to proxy API requests to the backend.

## Available Scripts

### Root `package.json`

-   `npm start`: Starts the React development server.
-   `npm run build`: Builds the React app for production.
-   `npm run server`: A helper script to run the backend server from the root.
-   `npm run dev`: Runs both the frontend and backend concurrently.

### `server/package.json`

-   `npm start`: Starts the backend server using `node`.
-   `npm run dev`: Starts the backend server using `nodemon`, which automatically restarts on file changes.

## API Endpoints

The backend exposes the following REST API endpoints:

-   `POST /api/v1/execute`
    -   Submits code for execution.
    -   **Body:** `{ "language": "cpp", "code": "..." }`
    -   **Returns:** `{ "jobId": "...", "status": "pending" }`

-   `GET /api/v1/job-status/:jobId`
    -   Polls for the status and result of an execution job.
    -   **Returns:**
        -   `{ "status": "completed", "result": "..." }`
        -   `{ "status": "failed", "error": "..." }`
        -   `{ "status": "waiting" | "active" }`

## Security and Resource Management

-   **Container Isolation:** Each code execution runs in a new, isolated Docker container.
-   **Resource Limits:** Containers are restricted in their memory and CPU usage to prevent abuse.
-   **Network Isolation:** Networking is disabled within the containers to prevent external calls.
-   **Read-only Filesystem:** The submitted code is mounted as a read-only file to prevent modification.
-   **Seccomp Profiles:** On Linux, a seccomp profile is applied to restrict the available system calls, further hardening the sandbox.
-   **Execution Timeouts:** A timeout is enforced on each execution to prevent long-running or infinite-loop processes.

## Supported Languages

| Language   | Identifier   |
| :--------- | :----------- |
| C++        | `cpp`        |
| Java       | `java`       |
| Python     | `python`     |
| JavaScript | `javascript` |

## Troubleshooting

-   **Docker Not Running:** Ensure the Docker daemon is active. The application cannot execute code without it.
-   **Redis Connection Issues:** Verify that Redis is running and accessible at the `REDIS_URL` specified in your `server/.env` file.
-   **`EPERM` or `seccomp` Errors:** The seccomp profile for Docker is Linux-specific. On Windows or macOS, the application gracefully ignores it, relying on Docker's default security. These errors are non-critical on non-Linux systems.
-   **Syntax Validation Failures:** For local syntax validation to work, you must have the necessary compilers/interpreters (`g++`, `javac`, `python3`, `node`) installed and available in your system's `PATH`.

## Contributing

Contributions are welcome! Please feel free to open an issue to report a bug or suggest a feature, or submit a pull request with your improvements.

1.  Fork the repository.
2.  Create a new feature branch (`git checkout -b feature/your-feature`).
3.  Commit your changes (`git commit -m 'Add some feature'`).
4.  Push to the branch (`git push origin feature/your-feature`).
5.  Open a Pull Request.
