# MAX AI Assistant Workspace

This workspace contains the complete codebase for the MAX AI Operating System Assistant, divided into the **Flutter Mobile App** and the **FastAPI Backend**.

---

## Workspace Structure

- `/max` - Flutter Mobile application codebase (Android-focused system control, Voice, Vision UI, Permissions, and Developer Tools).
- `/backend` - FastAPI Python server powering Llama 3 Chat, Streaming SSE, RAG Document Parsing, and Vector Embeddings.
- `/tests` - Integration and backend unit tests.

---

## Local Development Setup

### 1. Backend
Navigate to `/backend`:
```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### 2. Flutter App
Navigate to `/max`:
```bash
cd max
flutter pub get
flutter run
```

---

## Deployment to GitHub

To push this repository to your remote GitHub repository (`https://github.com/Keyan404/Max`), follow these commands:

1. **Configure Git Remotes:**
   ```bash
   git remote add origin https://github.com/Keyan404/Max
   ```

2. **Add Files and Commit:**
   ```bash
   git add .
   git commit -m "feat: complete secure MAX AI system, settings, permissions and backend services"
   ```

3. **Push to GitHub:**
   ```bash
   git branch -M main
   git push -u origin main
   ```

*Note: Sensitive credentials (like `.env` and `google-services.json`) are automatically ignored via `.gitignore` to prevent leakage.*

---

## Deploying Backend to Render

Follow these exact steps to deploy the FastAPI backend on **Render.com**:

1. **Log in to Render Dashboard:**
   Go to [dashboard.render.com](https://dashboard.render.com/) and click **New** -> **Web Service**.
2. **Connect Repository:**
   Connect your GitHub account and select your **Max** repository.
3. **Configure Service Details:**
   - **Name:** `max-backend` (or custom name)
   - **Region:** Select closest to you
   - **Branch:** `main`
   - **Root Directory:** `backend` (This is very important!)
   - **Runtime:** `Python`
   - **Build Command:** `pip install -r requirements.txt`
   - **Start Command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
4. **Configure Environment Variables:**
   Under **Advanced** -> **Environment Variables**, add the following keys:
   - `GROQ_API_KEY`: *[Your Groq API Key]*
   - `FIREBASE_CREDENTIALS_JSON`: *[Raw JSON string content of your Firebase Service Account private key file]*
5. **Deploy:**
   Click **Create Web Service**. Your backend will build and start streaming SSE completions securely!
