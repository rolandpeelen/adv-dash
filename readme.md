I'm traveling from AMS to CPT on my motorbike and for that I need navigation. Not satisfied with the alternatives, I decided to create a basic navigation app.

Done
- Create basic app with map / download capabilities
- Load GPX from file

Todo
- ~Based on some parameters, create a boundary around that line and download everything within as an offline map -- IE. implement http://188.166.7.120:5000/ algorithm to draw the bounding boxes~ -- This is no longer necessary. The exported GPX files contain so many points that the other algorithm won't really work. 
- Connect to AWS bucket to select GPX file

Todo Back-end
- Create tiny back-end with user management for easy selection of GPX files
- Have back-end be able to upload GPX files

To use:
- Clone
- Copy stuff below, put in `rally-gpx/Info.plist` and replaced the `<<token>>` with your own mapbox token
- Pod install

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
	<key>CFBundleIdentifier</key>
	<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$(PRODUCT_NAME)</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSRequiresIPhoneOS</key>
	<true/>
	<key>UILaunchStoryboardName</key>
	<string>LaunchScreen</string>
	<key>UIMainStoryboardFile</key>
	<string>Main</string>
	<key>UIRequiredDeviceCapabilities</key>
	<array>
		<string>armv7</string>
	</array>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>UISupportedInterfaceOrientations~ipad</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
		<string>UIInterfaceOrientationPortraitUpsideDown</string>
		<string>UIInterfaceOrientationLandscapeLeft</string>
		<string>UIInterfaceOrientationLandscapeRight</string>
	</array>
	<key>MGLMapboxAccessToken</key>
	<string><<token>></string>
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Shows your location on the map and helps improve OpenStreetMap.
</string>
</dict>
</plist>
```
