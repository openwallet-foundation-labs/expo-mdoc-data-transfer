require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'MdocDataTransfer'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.author         = package['author']
  s.homepage       = package['homepage']
  s.platforms      = { :ios => '16.0'}
  s.swift_version  = '5.4'
  s.source         = { :git => "https://github.com/animo/mdoc-data-transfer.git", :tag => "#{s.version}" }
  s.static_framework = true

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }

  s.source_files = "ios/**/*.{h,m,mm,swift}"
  
  s.dependency 'ExpoModulesCore'

  install_modules_dependencies(s)

  if defined?(:spm_dependency)
    spm_dependency(s,  
      url: 'https://github.com/eu-digital-identity-wallet/eudi-lib-ios-iso18013-security.git', 
      requirement: {kind: 'upToNextMinorVersion', minimumVersion: '0.8.2'}, 
      products: ['MdocSecurity18013'] 
    ) 
    spm_dependency(s,  
      url: 'https://github.com/eu-digital-identity-wallet/eudi-lib-ios-wallet-storage.git', 
      requirement: {kind: 'upToNextMinorVersion', minimumVersion: '0.8.4'}, 
      products: ['WalletStorage'] 
    ) 
  else 
    raise "Please upgrade React Native to >=0.75.0 to use SPM dependencies." 
  end 
end
