Pod::Spec.new do |s|
  s.name         = "Aspects"
  s.version      = "1.4.1"
  s.summary      = "Delightful, simple library for aspect oriented programming."
  s.homepage     = "https://github.com/steipete/Aspects"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Peter Steinberger" => "steipete@gmail.com" }
  s.ios.deployment_target = '6.0'
  s.osx.deployment_target = '10.7'
  s.source       = { :git => "https://github.com/steipete/Aspects.git", :tag => "#{s.version}" }
  s.source_files  = 'Aspects.{h,m}'
  s.requires_arc = true;
  s.social_media_url = "https://twitter.com/steipete"
end
