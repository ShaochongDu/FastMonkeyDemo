# FastMonkeyDemo
目前使用Xcode 10.1运行测试


## 前提

* [安装Homebrew](https://www.jianshu.com/p/de6f1d2d37bf)

* 安装以下工具

	```
	brew uninstall ideviceinstaller
	brew uninstall libimobiledevice
	brew install --HEAD libimobiledevice
	brew link --overwrite libimobiledevice
	brew install ideviceinstaller
	brew link --overwrite ideviceinstaller	
	```

## Fastmonkey依赖库添加

* 下载[Fastmonkey](https://github.com/zhangzhao4444/Fastmonkey)

* 修改XCTestWD-master目录中Cartfile文件 

	* Xcode 9.2 配置

		```
		github "glock45/swifter" == 1.3.3
		github "SwiftyJSON/SwiftyJSON" == 3.1.4
		github "cezheng/Fuzi" ~> 1.0.1
		github "tadija/AEXML" == 4.1.0
		github "CocoaLumberjack/CocoaLumberjack" == 3.4.2
		```


	* Xcode 10.1 配置，使用[master分支](https://github.com/zhangzhao4444/Fastmonkey/tree/master/XCTestWD-master)

		```
		github "httpswift/swifter" == 1.4.3
		github "SwiftyJSON/SwiftyJSON"==4.0.0
		github "cezheng/Fuzi" ~> 2.1.0
		github "tadija/AEXML" == 4.2.2
		github "CocoaLumberjack/CocoaLumberjack"==3.5.2
		github "Quick/Nimble"
		```


* 下载依赖文件，在目录XCTestWD-master下与Cartfile文件平级
 
	`Carthage update --platform iOS`


## Xcode配置

	* 选择Xcode编译版本

		* 可以使用Xcode 10.1版本进行编译，打开Xcode -> Preferences -> Locations -> Command Line Tools 选择Xcode 10.1

	* 开发者证书及签名相关配置

	* 低版本Xcode运行高版本真机（如:Xcode 9.2运行iOS 11.x、Xcode 10.1运行iOS 12.X）

		* 可下载最新版本Xcode，找到对应安装App（一般在‘应用程序’目录中），右键 显示包内容 ▸ ⁨Contents⁩ ▸ ⁨Developer⁩ ▸ ⁨Platforms⁩ ▸ ⁨iPhoneOS.platform⁩ ，将该		目录下需要的包拷贝到Xcode 9.2/Xcode 10.1 App对应的目录中即可


## Fastmonkey运行

* 修改执行App的bundleID

	* 查找文件XCTestWDMonkey.swift
	
	* let bundleID = "App bundleID"


* 其他配置修改

	* 查找文件Monkey.swift

	```
	let elapsedTime = 0  //  自动化测试执行时长
	let throttle = 0 * 1000   //  两个事件点击间隔时长
	```


* 开启自动化测试

	* 直接使用Xcode运行

		* 选择XCTestWDUnitTest工程并使用真机，执行 command + u 开启UITest
	
	* 命令启动（支持多设备）	

		* 进入 XCTestWD 所在目录

		* 执行以下命令

			```
			xcodebuild -project XCTestWD.xcodeproj \
			-scheme XCTestWDUITests \
			-destination 'platform=iOS,name=Analysys_01' \
			XCTESTWD_PORT=8001 \
			clean test
			```
			
 			注：Analysys_01：修改为运行手机的名称；8001：不同手机修改不同端口号；


##  其他参考
    
* [Xcode9.2环境搭建FastMonkey进行Monkey测试](https://www.jianshu.com/p/373c14d014f2)

* [fastmonkey 压力测试](https://www.cnblogs.com/wallis123/p/10615397.html)







