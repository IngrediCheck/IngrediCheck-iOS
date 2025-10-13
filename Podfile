# Uncomment the next line to define a global platform for your project
platform :ios, '17.2'

target 'IngrediCheck' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for IngrediCheck
  pod 'GoogleMLKit/TextRecognition', '9.0.0'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f <  12.0
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
      end
      if target.name.start_with? "GoogleToolboxForMac"
        config.build_settings['CLANG_WARN_STRICT_PROTOTYPES'] = 'NO'  
      end
    end
  end
end
