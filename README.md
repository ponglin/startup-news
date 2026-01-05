# Startup News - 創業創投資訊平台

一個由 Google AI Studio (Gemini)、Google Cloud Platform 和現代前端技術驅動的全自動新聞聚合平台。

## 平台簡介

本平台整合來自台灣五大新創生態系統資訊源的最新消息，包括：
- SparkLabs Taiwan
- Startup 101 
- 886 Studios
- 500 Global
- AppWorks

每日自動抓取最新文章，透過 Gemini 進行智能處理與總結。

## 技術架構

- 資料抓取層: Cloud Functions + Puppeteer
- AI 處理層: Google Gemini API 1.5 Pro
- 儲存層: Firestore Database
- 排程層: Cloud Scheduler (每日執行)
- 前端: Next.js + React + Tailwind CSS
- 部署: Firebase Hosting + Cloud Run

## 項目文件

已通過 Google AI Studio (Gemini) 完整生成：

### 前端應用
- frontend/app.tsx, next.config.js, package.json
- components/ArticleCard.tsx
- App.tsx, index.tsx

### 後端函數
- functions/index.ts, package.json

### 配置檔案
- cloudbuild.yaml, firebase.json
- firestore.rules, firestore.indexes.json
- package.json, metadata.json

### 基礎設施
- terraform/main.tf

### 部署自動化
- .github/workflows/deploy.yml
- deploy.sh, DEPLOYMENT_CHECKLIST.md

### 服務
- services/geminiService.ts
- constants.ts, types.ts

## 快速開始

### 前置需求
- Google Cloud Platform 帳戶
- GitHub 帳戶  
- Node.js 18+
- Terraform 1.5+

### 部署步驟

```bash
bash deploy.sh init
terraform apply
cd frontend && npm run build && firebase deploy
```

## 部署驗證

1. 訪問 Firebase 部署的應用URL
2. 驗證 Cloud Functions 已部署
3. 檢查 Cloud Scheduler 每日任務
4. 確認 Firestore 有最新文章數據

## 故障排除

遇到 \"project: required field is not set\" 錯誤？
- 設置環境變數: export PROJECT_ID=your-gcp-project-id

Terraform 初始化失敗？
- gcloud auth application-default login

## 常見問題

Q: 多久更新一次？
A: 每天自動更新，可根據需求調整頻率

Q: 成本如何？
A: 使用免費額度可支持中等流量；Gemini API 按使用量計費

---

MIT License - 歡迎貢獻！
