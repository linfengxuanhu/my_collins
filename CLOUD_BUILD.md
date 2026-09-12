# 云端编译 APK

这个项目已经带 GitHub Actions 配置，不需要在本机打开 Android Studio。

## 第一次使用
1. 在 GitHub 新建一个空的私有仓库，例如 `my-collins`。
2. 把本项目所有文件上传到仓库，确保 `.github/workflows/build-apk.yml` 也上传。
3. 打开仓库的 **Actions**。
4. 选择 **Build Android APK**。
5. 点击 **Run workflow**。
6. 编译完成后进入这次运行记录，在 **Artifacts** 下载 `my-collins-apk`。
7. 解压后得到 `app-release.apk`，发送到安卓手机安装。

## 注意
- GitHub Actions 负责在云端安装 Flutter/Android 构建环境并编译。
- 本仓库当前没有提交 `android/` 目录，工作流会在云端执行 `flutter create --platforms=android .` 自动生成 Android 工程。
- 这是测试版 APK 构建流程；正式发布到应用商店时还需要签名配置。V10 还会先执行 flutter analyze，如果代码有问题会在这一步直接显示具体错误。
