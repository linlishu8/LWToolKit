Pod::Spec.new do |s|
  s.name         = 'LWToolKit'
  s.version      = '1.0.19'
  s.summary      = 'iOS 工具包：Core、UI、Media、Analytics、Network 等基础能力。'
  s.description  = <<-DESC
长期可用的轻量 iOS 基础工具包，包含节流/防抖、任务队列、Keychain、缓存、本地化、AB 实验、通知、深链路由、UI 组件（Toast/Alert）、媒体选择与加载、事件上报，以及基于 Alamofire 的网络层等模块。
  DESC
  s.homepage     = 'https://github.com/linlishu8/LWToolKit'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.authors      = { 'linlishu8' => 'linlishu8@163.com' }
  s.source       = { :git => 'https://github.com/linlishu8/LWToolKit.git', :tag => s.version.to_s }

  s.platform       = :ios, '14.0'
  s.swift_versions = ['5.9', '6.0']
  s.requires_arc   = true

  s.default_subspecs = ['All']

  s.subspec 'LWUI' do |ss|
    ss.source_files = ['Sources/LWUI/**/*{h,m,mm,swift}', 'LWToolKit/Sources/LWUI/**/*{h,m,mm,swift}']
    ss.frameworks = %w(UIKit UserNotifications Network Security PhotosUI UniformTypeIdentifiers AppTrackingTransparency)
    ss.dependency 'LWToolKit/LWCore'
  end
  s.subspec 'LWMedia' do |ss|
    ss.source_files = ['Sources/LWMedia/**/*{h,m,mm,swift}', 'LWToolKit/Sources/LWMedia/**/*{h,m,mm,swift}']
    ss.frameworks = %w(UIKit UserNotifications Network Security PhotosUI UniformTypeIdentifiers AppTrackingTransparency)
    ss.dependency 'LWToolKit/LWCore'
  end
  s.subspec 'LWAnalytics' do |ss|
    ss.source_files = ['Sources/LWAnalytics/**/*{h,m,mm,swift}', 'LWToolKit/Sources/LWAnalytics/**/*{h,m,mm,swift}']
    ss.frameworks = %w(UIKit UserNotifications Network Security PhotosUI UniformTypeIdentifiers AppTrackingTransparency)
    ss.dependency 'LWToolKit/LWCore'
  end
  s.subspec 'LWNetwork' do |ss|
    ss.source_files = ['Sources/LWNetwork/**/*{h,m,mm,swift}', 'LWToolKit/Sources/LWNetwork/**/*{h,m,mm,swift}']
    ss.dependency 'LWToolKit/LWCore'
    ss.dependency 'Alamofire', '~> 5.8'
    ss.frameworks = %w(Network Security)
  end
  end # All subspec

  # 聚合 All：包含检测到的模块
  s.subspec 'All' do |ss|
    ss.dependency 'LWToolKit/LWCore'
    ss.dependency 'LWToolKit/LWUI'
    ss.dependency 'LWToolKit/LWMedia'
    ss.dependency 'LWToolKit/LWAnalytics'
    ss.dependency 'LWToolKit/LWNetwork'
  end
  s.default_subspecs = ['All']
end
