# ios_sdk

iOS SDK宗旨：展示如何在iOS平台上使用优图开放平台开放的图像服务, 不能作为sdk使用。

iOS SDK包含：
  1. 如何进行鉴权
  2. 如何对参数进行封装
  3. 如何使用iOS API来发送GET或POST请求
  4. 如何把服务器返回的结果转换为NSDictionary

demo展示如何调用优图开放平台API接口，网络请求返回的数据以log形式展示，请开发者用XCode查看，是根据 http://open.youtu.qq.com/welcome/developer#/api-summary 实现的。

请开发者根据自己的需求，按照SDK中实现方式，封装http://open.youtu.qq.com/welcome/developer#/api-summary 列出的API


如果遇到问题，请按以下步骤解决：
  1. 阅读iOS SDK源码
  2. 在http://open.youtu.qq.com/welcome/developer#/api-summary 阅读发送参数、返回结果含义
  3. 请联系我们
  
##注意：
	人脸核身相关接口，需要申请权限接入，具体参考http://open.youtu.qq.com/welcome/service#/solution-facecheck
	人脸核身接口包括：
	- (void)idcardOcrFaceIn:(id)image cardType:(NSInteger)cardType successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	- (void)faceCompareFaceIn:(id)imageA imageB:(id)imageB successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	- (void)idcardfacecompare:(NSString*)idCardNumber withName:(NSString*)idCardName image:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	- (void)livegetfour:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	- (void)livedetectfour:(NSData*)video image:(id)image validateId:(NSString*) validateData isCompare:(BOOL)isCompare successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	- (void)idcardlivedetectfour:(NSData*)video withId:(NSString*)idCardNumber withName:(NSString*)idCardName validateId:(NSString*) validateData successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	

##名词：
- AppId 平台添加应用后分配的AppId
- SecretId 平台添加应用后分配的SecretId
- SecretKey 平台添加应用后分配的SecretKey
- 签名 接口鉴权凭证，由AppId、SecretId、SecretKey等生成，详见	http://open.youtu.qq.com/welcome/new-authentication


## 使用示例

##### 设置APP 鉴权信息
		Conf.m里设置自己申请的 APP_ID, SECRET_ID, SECRET_KEY
		-(instancetype)init{
    		self = [super init];
    		_appId = @"your appid";        		// 替换APP_ID
    		_secretId = @"your secretId";    	// 替换SECRET_ID
    		_secretKey = @"your secretkey";   	// 替换SECRET_KEY
    		_API_END_POINT = API_END_POINT;
    		_API_VIP_END_POINT = API_VIP_END_POINT;
    		return self;
		}
	
##### 根据你使用的平台选择一种初始化方式
	优图开放平台初始化
	NSString *auth = [Auth appSign:1000000 userId:nil];
    TXQcloudFrSDK *sdk = [[TXQcloudFrSDK alloc] initWithName:[Conf instance].appId authorization:auth endPoint:[Conf instance].API_END_POINT];

	优图开放平台核身服务初始化（**核身服务目前仅支持核身专有接口,需要联系商务开通**）
	NSString *auth = [Auth appSign:1000000 userId:nil];
    TXQcloudFrSDK *sdk = [[TXQcloudFrSDK alloc] initWithName:[Conf instance].appId authorization:auth endPoint:[Conf instance].API_VIP_END_POINT];
    
##### 调用示例
    UIImage *local = [UIImage imageNamed:@"id.jpg"];
    id image = local;
    [sdk detectFace:image successBlock:^(id responseObject) {
        NSLog(@"responseObject: %@", responseObject);
    } failureBlock:^(NSError *error) {
        NSLog(@"error");
    }];
    

##接口说明：
####接口分为开放平台免费接口和人脸核身接口，人脸核身接口访问权限需要联系商务开通；开放平台接口访问域名为https://api.youtu.qq.com/， 人脸核身接口访问域名为https://vip-api.youtu.qq.com/


	构造方法
	- (id)initWithName:(NSString *)_appid authorization:(NSString *)_authorization endPoint:(NSString *)endpoint;
	参数：
	appid 授权appid
	secret_id 授权secret_id
	secret_key 授权secret_key
	end_point  域名（开放平台接口访问域名为：https://api.youtu.qq.com/，人脸核身接口访问域名为：https://vip-api.youtu.qq.com/）

###开放平台免费接口说明
	人脸检测，检测给定图片(Image)中的所有人脸(Face)的位置和相应的面部属性。位置包括(x, y, w, h)， 面部属性包括性别(gender), 年龄(age), 表情(expression), 眼镜(glass)和姿态(pitch，roll，yaw).
	- (void)detectFace:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 人脸图片

	五官定位
	- (void)faceShape:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 人脸图片

	人脸对比， 计算两个Face的相似性以及五官相似度。
	- (void)faceCompare:(id)imageA imageB:(id)imageB successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	imageA 第一张人脸图片
	imageB 第二张人脸图片


	人脸识别，对于一个待识别的人脸图片，在一个Group中识别出最相似的Top5 Person作为其身份返回，返回的Top5中按照相似度从大到小排列。
	- (void)faceIdentify:(id)image groupId:(NSString *)groupId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 需要识别的人脸图片
	groupId 人脸face组

	创建一个Person，并将Person放置到group_ids指定的组当中
	- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *) groupIds personName:(NSString*) personName successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 需要新建的人脸图片
	personId 指定创建的人脸
	groupIds 加入的group列表
	personName 名字

	创建一个Person，并将Person放置到group_ids指定的组当中
	- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *) groupIds successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 需要新建的人脸图片
	personId 指定创建的人脸
	groupIds 加入的group列表

	增加一个人脸Face.将一组Face加入到一个Person中。注意，一个Face只能被加入到一个Person中。一个Person最多允许包含100个Face。
	- (void)addFace:(NSString *)personId imageArray:(NSArray *)imageArray successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	personId 人脸Face的person id
	imageArray 人脸图片UIImage列表

	删除一个person下的face，包括特征，属性和face_id.
	- (void)delFace:(NSString *)personId faceIdArray:(NSArray *)faceIdArray successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	personId 待删除人脸的person ID
	faceIdArray 删除人脸id的列表

	设置Person的name.
	- (void)setInfo:(NSString *)personName personId:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	personName新的name
	personId 要设置的person id

	获取一个Person的信息, 包括name, id, tag, 相关的face, 以及groups等信息。
	- (void)getInfo:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	personId  待查询个体的ID

	获取一个AppId下所有group列表
	- (void)getGroupIdsWithsuccessBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;

	- (void)getPersonIds:(NSString *)groupId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	groupId 待查询的组id

	获取一个组person中所有face列表
	- (void)getFaceIds:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	personId 待查询的个体id

	获取一个face的相关特征信息
	- (void)getFaceInfo:(NSString *)face_id successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	faceId 带查询的人脸ID

	删除一个Person
	- (void)delPerson:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	personId 要删除的person ID

	创建一个Person，并将Person放置到group_ids指定的组当中
	- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *)groupIds personName:(NSString *) personName personTag:(NSString *) personTag successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 需要新建的人脸图片
	personId 指定创建的人脸
	groupIds 加入的group列表
	personName 名字
	personTag 备注

	身份证OCR识别
	- (void)idcardOcr:(UIImage *)image cardType:(NSInteger)cardType sessionId:(NSString *)sessionId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 输入图片
	cardType 身份证图片类型，0-正面，1-反面
	sessionId 请求序列号，用于流水查询

 	名片OCR识别
	- (void)namecardOcr:(UIImage *)image sessionId:(NSString *)sessionId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 输入图片
	sessionId 请求序列号，用于流水查询


	判断一个图像的模糊程度
	- (void)fuzzyDetect:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 输入图片
	cookie 下载url时需要的cookie 信息
	seq 请求序列号，用于流水查询

 
	识别一个图像是否为美食图像
	- (void)foodDetect:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 输入图片
	cookie 当imagePath为url时，需要的cookie信息
	seq 请求序列号，用于流水查询

	识别一个图像的标签信息,对图像分类。
	- (void)imageTag:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 输入图片
	cookie 当imagePath为url时，需要的cookie信息
	seq 请求序列号，用于流水查询

	识别一个图像是否为色情图像
	- (void)imagePorn:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 输入图片
	cookie 当imagePath为url时，需要的cookie信息
	seq 请求序列号，用于流水查询



###人脸核身接口说明
####人脸核身接口访问域名为：https://vip-api.youtu.qq.com/，需要联系商务开通权限。

	身份证OCR识别
	- (void)idcardOcrFaceIn:(id)image cardType:(NSInteger)cardType successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	image 输入图片
	cardType 身份证图片类型，0-正面，1-反面

	人脸比对
	- (void)faceCompareFaceIn:(id)imageA imageB:(id)imageB successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	imageA 输入图片A
	imageB 输入图片B

	人脸比对:使用优图数据源比对
	- (void)idcardfacecompare:(NSString*)idCardNumber withName:(NSString*)idCardName image:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	idCardNumber 用户身份证号码
	idCardName 用户身份证姓名
	image 输入图片

	唇语获取
	- (void)livegetfour:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;

	视频人脸核身:用户自带数据源核身
	- (void)livedetectfour:(NSData*)video image:(id)image validateId:(NSString*) validateData isCompare:(BOOL)isCompare successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	video 需要检测的视频base64编码
	validateData livegetfour得到的唇语验证数据
	image 输入图片
	isCompare video中的照片和card是否做对比，True做对比，False不做对比

	视频人脸核身:使用优图数据源核身
	- (void)idcardlivedetectfour:(NSData*)video withId:(NSString*)idCardNumber withName:(NSString*)idCardName validateId:(NSString*) validateData successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
	参数：
	video 需要检测的视频base64编码
	idCardNumber 用户身份证号码
	idCardName 用户身份证姓名
	validateData livegetfour得到的唇语验证数据















