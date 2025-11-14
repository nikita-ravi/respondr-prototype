# Deploying to Streamlit Community Cloud

## Step 1: Push to GitHub

1. Initialize git repository (if not already done):
```bash
cd /Users/nikitaravi/Documents/respondr-prototype
git init
git add .
git commit -m "Initial commit: Respondr document metadata extraction pipeline"
```

2. Create a new repository on GitHub:
   - Go to https://github.com/new
   - Name: `respondr-prototype` (or any name you prefer)
   - Choose **Private** for security
   - **DO NOT** initialize with README (we already have one)
   - Click "Create repository"

3. Push to GitHub:
```bash
git remote add origin https://github.com/YOUR_USERNAME/respondr-prototype.git
git branch -M main
git push -u origin main
```

## Step 2: Deploy to Streamlit Cloud

1. Go to https://share.streamlit.io/

2. Click "New app"

3. Configure:
   - **Repository:** Select your `respondr-prototype` repo
   - **Branch:** main
   - **Main file path:** `dashboard/dashboard.py`
   - Click "Advanced settings"

4. Add AWS credentials as secrets:
   - In "Secrets" section, paste this (replace with YOUR credentials):

```toml
# AWS Credentials
AWS_ACCESS_KEY_ID = "YOUR_ACCESS_KEY_ID_HERE"
AWS_SECRET_ACCESS_KEY = "YOUR_SECRET_ACCESS_KEY_HERE"
AWS_DEFAULT_REGION = "us-east-1"
```

5. Click "Deploy!"

## Step 3: Get Your Credentials

Your AWS credentials are in: `config/dev_user_credentials.txt`

Run this to see them:
```bash
cat config/dev_user_credentials.txt
```

## Step 4: Share the Link

Once deployed, Streamlit will give you a URL like:
`https://YOUR_APP_NAME.streamlit.app`

Share this URL with your team!

## Security Notes

- The repository is **private** - only you can see the code
- AWS credentials are stored as **secrets** - not in the code
- The URL is **public** - anyone with the link can access
- Consider adding password protection for production use

## Troubleshooting

If the app doesn't load:
1. Check the logs in Streamlit Cloud
2. Verify AWS credentials are correct
3. Ensure all files are pushed to GitHub
4. Check that requirements-streamlit.txt has the right dependencies
