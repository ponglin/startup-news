# GitHub Actions 自動部署到 GCP - 完整設置指南

## 📋 概述

本指南將幫助您設置 **自動化 CI/CD 流程**，將代碼推送到 GitHub 時自動部署到 Google Cloud Platform。

## 🔐 第一步：準備 GCP 服務帳戶密鑰

### 1.1 建立服務帳戶

```bash
# 在 GCP Console 中執行
gcloud iam service-accounts create github-actions-deploy \
  --display-name="GitHub Actions Deployment"
```

### 1.2 分配必要的權限角色

```bash
# 賦予服務帳戶所需的角色
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions-deploy@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/editor"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions-deploy@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudfunctions.admin"

gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:github-actions-deploy@$GCP_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudscheduler.admin"
```

### 1.3 建立金鑰文件

```bash
# 建立 JSON 金鑰檔案
gcloud iam service-accounts keys create key.json \
  --iam-account=github-actions-deploy@$GCP_PROJECT_ID.iam.gserviceaccount.com

# 將其編碼為 Base64
cat key.json | base64
```

**重要**：複製輸出的 Base64 編碼字符串，稍後需要在 GitHub 中使用。

---

## 🔑 第二步：配置 GitHub Secrets

### 2.1 訪問 GitHub 倉庫設定

1. 前往：`https://github.com/ponglin/startup-news`
2. 點擊 **Settings** → **Secrets and variables** → **Actions**
3. 點擊 **New repository secret**

### 2.2 添加所有必需的 Secrets

添加以下 Secret（根據說明輸入相應值）：

| Secret 名稱 | 說明 | 取得方式 |
|-----------|------|--------|
| `GCP_PROJECT_ID` | 您的 GCP 項目 ID | GCP Console > 項目選擇器 |
| `GCP_SA_KEY` | 服務帳戶 Base64 編碼密鑰 | 上面第 1.3 步的輸出 |
| `FIREBASE_PROJECT` | Firebase 項目 ID | Firebase Console |
| `FIREBASE_TOKEN` | Firebase 認證令牌 | 執行 `firebase login:ci` |
| `GEMINI_API_KEY` | Google Gemini API 密鑰 | Google AI Studio |
| `NEXT_PUBLIC_API_URL` | 前端 API 端點 | 部署後的 Cloud Functions URL |

### 2.3 設置 Firebase Token

```bash
# 在本地執行（需要已安裝 Firebase CLI）
firebase login:ci

# 複製輸出的令牌字符串到 GitHub Secret: FIREBASE_TOKEN
```

---

## 🚀 第三步：觸發自動部署

### 選項 A：自動部署（推薦）

當您推送代碼到 `main` 分支時，自動觸發部署：

```bash
# 編輯您的代碼
git add .
git commit -m "Update deployment"
git push origin main

# GitHub Actions 會自動開始部署！
```

### 選項 B：手動部署

1. 前往倉庫 **Actions** 標籤
2. 選擇 **Deploy to GCP** 工作流
3. 點擊 **Run workflow**
4. 選擇環境（staging/production）
5. 點擊 **Run workflow**

---

## 📊 監控部署進度

### 查看工作流運行

1. 前往 **Actions** 標籤
2. 選擇最新的 **Deploy to GCP** 運行
3. 查看每個步驟的詳細日誌

### 預期工作流步驟

1. ✅ **build-and-test** - 編譯和測試
2. ✅ **deploy-to-gcp** - 部署到 GCP
   - 驗證 GCP 身份
   - 啟用所需 API
   - 運行 Terraform
   - 部署 Firebase Hosting
   - 部署 Cloud Functions
   - 設置 Cloud Scheduler
3. ✅ **notify-failure** - 失敗通知（如果失敗）

---

## ✅ 驗證部署成功

### 檢查清單

```bash
# 1. Firebase Hosting
echo "訪問: https://$FIREBASE_PROJECT.web.app"

# 2. Cloud Functions
gcloud functions describe scrapeStartupNews \
  --region=asia-east1

# 3. Cloud Scheduler
gcloud scheduler jobs describe startup-news-daily \
  --location=asia-east1

# 4. Firestore 數據
gcloud firestore documents list --collection-id=articles
```

---

## 🐛 故障排除

### 部署失敗時

1. 前往 **Actions** 標籤
2. 點擊失敗的工作流運行
3. 展開失敗的步驟查看詳細錯誤
4. 常見問題：

#### 錯誤："Secret not found"
- ✅ 確認所有必需的 Secret 已添加
- ✅ Secret 名稱完全匹配（區分大小寫）

#### 錯誤："Permission denied"
- ✅ 確認服務帳戶有正確的 IAM 角色
- ✅ 檢查 GCP_SA_KEY 的有效性

#### 錯誤："Terraform initialization failed"
- ✅ 確保 GCP_PROJECT_ID Secret 正確
- ✅ 確認 GCP 專案已啟用 Terraform API

---

## 📝 環境變數

工作流使用以下環境變數（自動設置）：

```yaml
GCP_REGION: asia-east1
FIREBASE_PROJECT: 自動從 Secret 讀取
PROJECT_ID: 自動從 Secret 讀取
```

---

## 🔄 自訂部署流程

### 修改部署觸發器

編輯 `.github/workflows/deploy-gcp.yml` 中的 `on:` 部分：

```yaml
on:
  push:
    branches: [main, staging]  # 添加更多分支
  schedule:
    - cron: '0 2 * * *'  # 每天 2 AM UTC 自動部署
```

### 修改部署區域

編輯 `.github/workflows/deploy-gcp.yml` 中的：

```yaml
env:
  GCP_REGION: asia-east1  # 更改為您偏好的區域
```

---

## 💡 最佳實踐

✅ 定期備份 GCP 服務帳戶密鑰  
✅ 為不同環境使用不同的服務帳戶  
✅ 監控工作流日誌以檢測問題  
✅ 在推送到 main 前在 staging 分支測試  
✅ 保持 GitHub Actions 工作流與部署指令同步  

---

## 📞 支援

如需幫助，請：
1. 查看 GitHub Actions 日誌
2. 檢查 GCP Console 中的錯誤消息
3. 驗證所有 Secret 已正確配置
4. 查看 Terraform 輸出以了解基礎設施問題

---

**部署成功！** 🎉
