# AI画廊 App Store 上架准备清单

## Build

- App name: `AI画廊`
- Bundle ID: `com.maplemock.aigallery`
- Version: `1.0`
- Build: `1`
- Team ID: `2FTM6M6J55`
- Pricing: Free
- Archive: `/Users/maplemock/Applications/AIGallery/Archives/AIGallery.xcarchive`

## App Store Connect Blocker

`xcodebuild -exportArchive` was blocked by account/provisioning permissions:

- Xcode account session expired: `mock272767@gmail.com`
- Account does not currently have permission to create `iOS App Store` provisioning profiles.
- No App Store distribution profile was found for `com.maplemock.aigallery`.

Required action in Xcode:

1. Open Xcode > Settings > Accounts.
2. Re-login to the Apple ID and complete two-factor authentication.
3. Confirm the account is in an Apple Developer Program team with App Store Connect access.
4. Ensure the role can create Certificates, Identifiers & Profiles, or ask the Account Holder/Admin to create an App Store distribution profile.
5. Re-run export/upload using `ExportOptions-AppStore-Upload.plist`.

## Privacy

The app does not request camera, photo library, location, contacts, microphone, Bluetooth, HealthKit, or tracking permissions.

Recommended App Privacy answer:

- Data Collected: No
- Tracking: No
- Third-party advertising: No
- App uses HTTPS to load generated artwork images from Pollinations.
- No user accounts and no user-generated content is stored by this app.

`PrivacyInfo.xcprivacy` is included and declares:

- `NSPrivacyCollectedDataTypes`: empty
- `NSPrivacyTracking`: false
- `NSPrivacyTrackingDomains`: empty
- `NSPrivacyAccessedAPITypes`: empty

## Export Compliance

`ITSAppUsesNonExemptEncryption` is set to `false`.

Recommended App Store Connect export compliance answer:

- Uses encryption: No, beyond standard Apple OS HTTPS networking.

## Review Notes

Suggested notes for App Review:

`AI画廊 is a free visual inspiration gallery for AI-style artwork. The app does not require login and does not collect personal data. Image prompts are constrained to public-gallery-safe content, and unsafe search terms are filtered locally before image URLs are generated.`

## Suggested Metadata

Subtitle:

`在线 AI 视觉灵感画廊`

Promotional text:

`探索电影感、生成艺术、超现实、产品渲染和空间建筑等 AI 视觉方向。`

Description:

`AI画廊是一款免费的视觉灵感应用，用简洁的图片社区界面展示多种 AI 图像风格。你可以浏览精选作品、按热门标签发现不同方向，并收藏喜欢的视觉灵感。应用不需要登录，不收集个人数据，搜索词会在本地过滤后再生成安全的在线图片链接。`

Keywords:

`AI,画廊,艺术,设计,灵感,生成艺术,视觉,图片`

Support URL:

`https://pollinations.ai`

Age rating recommendation:

`4+`
