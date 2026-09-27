# 第三方资源许可证管理

本目录记录项目使用的所有第三方资源及其许可证信息。

## Godot引擎

- **名称**：Godot Engine
- **版本**：4.7.2 stable
- **许可证**：MIT License
- **来源**：https://godotengine.org/
- **用途**：游戏引擎
- **署名要求**：无
- **修改**：否

许可证全文见：https://github.com/godotengine/godot/blob/master/LICENSE.txt

## GodotSteam

- **名称**：GodotSteam
- **版本**：4.22
- **许可证**：MIT License
- **来源**：https://godotsteam.com/
- **用途**：Steamworks集成
- **署名要求**：无
- **修改**：否

## Steamworks SDK

- **名称**：Steamworks SDK
- **版本**：1.65
- **许可证**：Steamworks SDK License (专有，仅限Steam游戏使用)
- **来源**：https://partner.steamgames.com/
- **用途**：Steam平台功能
- **署名要求**：无
- **修改**：否

注意：Steamworks SDK仅在Steam版本中使用，不包含在源码仓库中。

## 资源登记模板

新增第三方资源时，在此目录创建 `<资源名>.md` 或 `<资源名>.yaml`：

```yaml
asset_name: 资源包名称
author: 作者
source_url: 来源URL
license: CC0 1.0 / MIT / CC BY 4.0 / 等
download_date: YYYY-MM-DD
modified: true/false
credit_required: true/false
used_in: 
  - 使用位置1
  - 使用位置2
notes: 额外说明
```

## 许可证合规检查清单

发布前必须确认：

- [ ] 所有第三方资源已登记
- [ ] 需要署名的资源已在游戏内Credits显示
- [ ] 不允许商用的资源已替换或获得授权
- [ ] Steamworks SDK仅在Steam版本使用
- [ ] 字体文件已确认游戏内嵌入许可
