Pod::Spec.new do |s|
  s.name         = "LWToolKit"
  s.version      = "1.0.17"
  s.summary      = "iOS 工具包：Core、UI、Media、Analytics、Network 等基础能力。"
  s.description  = <<-DESC
长期可用的轻量 iOS 基础工具包，包含节流/防抖、任务队列、Keychain、缓存、本地化、AB 实验、通知、深链路由、UI 组件（Toast/Alert）、媒体选择与加载、事件上报，以及基于 Alamofire 的网络层等模块。
  DESC
  s.homepage     = "https://github.com/linlishu8/LWToolKit"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.authors      = { "linlishu8" => "linlishu8@163.com" }
  s.source       = { :git => "https://github.com/linlishu8/LWToolKit.git", :tag => s.version.to_s }

  s.platform       = :ios, "14.0"
  s.swift_versions = ["5.9", "6.0"]
  s.requires_arc   = true

  # 默认安装所有模块
  s.default_subspecs = ['All']

  # 聚合子规格：只做依赖汇总，不直接声明源码
  s.subspec "All" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.dependency "LWToolKit/LWUI"
    ss.dependency "LWToolKit/LWMedia"
    ss.dependency "LWToolKit/LWAnalytics"
    ss.dependency "LWToolKit/LWNetwork"
  end

  # ---- 各模块 ----

  s.subspec "LWCore" do |ss|
    ss.source_files = "LWToolKit/Sources/LWCore/**/*.{h,m,mm,swift}"
    ss.frameworks = %w(UIKit UserNotifications Network Security)
    # 如确实使用了以下框架，可按需加入：
    # ss.frameworks += %w(AppTrackingTransparency UniformTypeIdentifiers PhotosUI)
  end

  s.subspec "LWUI" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "LWToolKit/Sources/LWUI/**/*.{h,m,mm,swift}"
    ss.frameworks = %w(UIKit)
  end

  s.subspec "LWMedia" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "LWToolKit/Sources/LWMedia/**/*.{h,m,mm,swift}"
    ss.frameworks = %w(PhotosUI UniformTypeIdentifiers)
  end

  s.subspec "LWAnalytics" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "LWToolKit/Sources/LWAnalytics/**/*.{h,m,mm,swift}"
  end

  s.subspec "LWNetwork" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.dependency "Alamofire", "~> 5.8"
    ss.source_files = "LWToolKit/Sources/LWNetwork/**/*.{h,m,mm,swift}"
    ss.frameworks = %w(Security Network)
  end
end
