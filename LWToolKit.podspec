Pod::Spec.new do |s|
  s.name         = "LWToolKit"
  s.version      = "1.0.4"
  s.summary      = "iOS 工具包：Core、UI、Media、Analytics 等基础能力。"
  s.description  = <<-DESC
一个长期可用的轻量 iOS 基础工具包，包含节流/防抖、任务队列、Keychain、缓存、本地化、AB 实验、通知、深链路由、到 UI 组件（Toast/Alert）、媒体选择与加载、事件上报等模块。
  DESC
  s.homepage     = "https://github.com/linlishu8/LWToolKit"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = { "linlishu8" => "linlishu8@163.com" }
  s.source       = { :git => "https://github.com/linlishu8/LWToolKit.git", :tag => s.version.to_s }

  s.platform     = :ios, "14.0"
  s.swift_versions = ["5.9", "5.10"]

  s.default_subspec = "LWCore"

  s.subspec "LWCore" do |ss|
    ss.source_files = "Sources/LWCore/**/*.{h,m,swift}"
    ss.ios.frameworks = %w(UIKit UserNotifications)   # 明确声明
  end

  s.subspec "UI" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "Sources/LWUI/**/*.{h,m,swift}"
  end

  s.subspec "Media" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "Sources/LWMedia/**/*.{h,m,swift}"
  end

  s.subspec "Analytics" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "Sources/LWAnalytics/**/*.{h,m,swift}"
  end
  
  s.subspec "LWNetwork" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.dependency "Alamofire", "~> 5.8"
    ss.frameworks = "Security", "Network" 
    ss.source_files = "Sources/LWNetwork/**/*.{h,m,swift}"
  end
  s.subspec "LWAnalytics" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "Sources/LWAnalytics/**/*.{h,m,swift}"
  end


  s.subspec "LWMedia" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "Sources/LWMedia/**/*.{h,m,swift}"
  end


  s.subspec "LWUI" do |ss|
    ss.dependency "LWToolKit/LWCore"
    ss.source_files = "Sources/LWUI/**/*.{h,m,swift}"
  end

end
