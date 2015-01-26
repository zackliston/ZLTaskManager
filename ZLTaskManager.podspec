#
#  Be sure to run `pod spec lint ZLTaskManager.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|

  s.name         = "ZLTaskManager"
  s.version      = "0.1.0"
  s.summary      = "An objective-c library for managing, persisting, and retrying work."

  s.description  = <<-DESC
                   There are many ways to dispatch work with Objective-C, from Grand Central Dispatch to NSOperations however, none of these approaches handle persisting work. ZLTaskManager fills this void. With this library we can persist work from app launch to app launch. We can make sure this work is retried again and again until it succeeds (or until we decide to stop retrying it, more on this later). And thanks to this we can start work without adding endless failsafes to make sure that it is done correctly.
                   DESC

  s.homepage     = "https://github.com/zackliston/ZLTaskManager"

  s.license      = "MIT"

  s.author             = { "Zack Liston" => "zackmliston@gmail.com" }

  # ――― Platform Specifics ――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If this Pod runs only on iOS or OS X, then specify the platform and
  #  the deployment target. You can optionally include the target after the platform.
  #

    s.platform     = :ios, "7.0"


  # ――― Source Location ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Specify the location from where the source should be retrieved.
  #  Supports git, hg, bzr, svn and HTTP.
  #

s.source       = { :git => "https://github.com/zackliston/ZLTaskManager.git", :tag => "0.1.0"}


  # ――― Source Code ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  CocoaPods is smart about how it includes source code. For source files
  #  giving a folder will include any h, m, mm, c & cpp files. For header
  #  files it will include any header in the folder.
  #  Not including the public_header_files will make all headers public.
  #

    s.source_files  = "ZLTaskManager/Classes/*.{h,m}"


  # ――― Project Linking ―――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  Link your library with frameworks, or libraries. Libraries do not include
  #  the lib prefix of their name.
  #

s.dependencies = {
    'FMDB' => '2.4',
    'Reachability' => '3.2'
}




  # ――― Project Settings ――――――――――――――――――――――――――――――――――――――――――――――――――――――――― #
  #
  #  If your library depends on compiler flags you can set them in the xcconfig hash
  #  where they will only apply to your library. If you depend on other Podspecs
  #  you can include multiple dependencies to ensure it works.

    s.requires_arc = true


end
