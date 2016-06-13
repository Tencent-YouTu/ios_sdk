//
//  TXQcloudFrSDK.h
//  SimpleURLConnections
//
//  Created by kenxjgao on 15/9/9.
//
//

#import <UIKit/UIKit.h>

typedef void(^HttpRequestSuccessBlock)(id responseObject);
typedef void(^HttpRequestFailBlock)(NSError *error);

@interface TXQcloudFrSDK: NSObject

@property (nonatomic, copy, readwrite) NSString *API_END_POINT;
@property (nonatomic, copy, readwrite) NSString *appid;
@property (nonatomic, copy, readwrite) NSString *authorization;

/*!
 *   构造方法
 *
 * @input appid
 *            授权appid
 * @input authorization
 *            通过appid secretId和secretKey生成的鉴权密钥
*/
- (id)initWithName:(NSString *)_appid authorization:(NSString *)_authorization;
/*!
 * 人脸属性分析 检测给定图片(Image)中的所有人脸(Face)的位置和相应的面部属性。位置包括(x, y, w, h)，
 * 面部属性包括性别(gender), 年龄(age), 表情(expression), 眼镜(glass)和姿态(pitch，roll，yaw).
 *
 * @input image
 *            人脸图片
 * @return 请求json结果
*/
- (void)detectFace:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 五官定位
 *
 * @input image
 *            人脸图片
 */
- (void)faceShape:(id)image successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 人脸对比， 计算两个Face的相似性以及五官相似度。
 *
 * @input imageA
 *            第一张人脸图片
 * @input imageB
 *            第二张人脸图片
 */
- (void)faceCompare:(id)imageA imageB:(id)imageB successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 人脸验证，给定一个Face和一个Person，返回是否是同一个人的判断以及置信度。
 *
 * @input image
 *            需要验证的人脸图片
 * @input personId
 *            验证的目标person
*/
- (void)faceVerify:(id)image personId:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 人脸识别，对于一个待识别的人脸图片，在一个Group中识别出最相似的Top5 Person作为其身份返回，返回的Top5中按照相似度从大到小排列。
 *
 * @input image
 *            需要识别的人脸图片
 * @input groupId
 *            人脸face组
 */
- (void)faceIdentify:(id)image groupId:(NSString *)groupId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 创建一个Person，并将Person放置到group_ids指定的组当中
 *
 * @input image
 *            需要新建的人脸图片
 * @input personId
 *            指定创建的人脸
 * @input groupIds
 *            加入的group列表
 * @input personName
 *            名字
*/
- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *) groupIds personName:(NSString*) personName successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 创建一个Person，并将Person放置到group_ids指定的组当中
 *
 * @input image
 *            需要新建的人脸图片
 * @input personId
 *            指定创建的人脸
 * @input groupIds
 *            加入的group列表
 */
- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *) groupIds successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 增加一个人脸Face.将一组Face加入到一个Person中。注意，一个Face只能被加入到一个Person中。
 * 一个Person最多允许包含100个Face。
 *
 * @input personId
 *            人脸Face的person id
 * @input imageArray
 *            人脸图片UIImage列表
*/
- (void)addFace:(NSString *)personId imageArray:(NSArray *)imageArray successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 删除一个person下的face，包括特征，属性和face_id.
 *
 * @input personId
 *            待删除人脸的person ID
 * @input faceIdArray
 *            删除人脸id的列表
*/
- (void)delFace:(NSString *)personId faceIdArray:(NSArray *)faceIdArray successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 设置Person的name.
 *
 * @input personName
 *            新的name
 * @input personId
 *            要设置的person id
*/
- (void)setInfo:(NSString *)personName personId:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 获取一个Person的信息, 包括name, id, tag, 相关的face, 以及groups等信息。
 *
 * @input personId
 *            待查询个体的ID
*/
- (void)getInfo:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 获取一个AppId下所有group列表
 *
 * @input 请求json结果
 */
- (void)getGroupIdsWithsuccessBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 获取一个组Group中所有person列表
 *
 * @input groupId
 *            待查询的组id
*/
- (void)getPersonIds:(NSString *)groupId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 获取一个组person中所有face列表
 *
 * @input personId
 *            待查询的个体id
*/
- (void)getFaceIds:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 获取一个face的相关特征信息
 *
 * @input faceId
 *            带查询的人脸ID
*/
- (void)getFaceInfo:(NSString *)face_id successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 删除一个Person
 *
 * @input personId
 *            要删除的person ID
*/
- (void)delPerson:(NSString *)personId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 创建一个Person，并将Person放置到group_ids指定的组当中
 *
 * @input image
 *            需要新建的人脸图片
 * @input personId
 *            指定创建的人脸
 * @input groupIds
 *            加入的group列表
 * @input personName
 *            名字
 * @input personTag
 *            备注
*/
- (void)newPerson:(id)image personId:(NSString *)personId groupIds:(NSArray *)groupIds personName:(NSString *) personName personTag:(NSString *) personTag successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
#pragma mark - ID OCR
/*!
 * 身份证OCR识别
 *
 * @input image
 *            输入图片
 * @input cardType
 *            身份证图片类型，0-正面，1-反面
 * @input sessionId
 *            请求序列号，用于流水查询
 */
- (void)idcardOcr:(UIImage *)image cardType:(NSInteger)cardType sessionId:(NSString *)sessionId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 名片OCR识别
 *
 * @input image
 *            输入图片
 * @input sessionId
 *            请求序列号，用于流水查询
 */
- (void)namecardOcr:(UIImage *)image sessionId:(NSString *)sessionId successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
#pragma mark - Image Recognition
/*!
 * 判断一个图像的模糊程度
 *
 * @input image
 *            输入图片
 * @input cookie
 *            下载url时需要的cookie 信息
 * @input seq
 *            请求序列号，用于流水查询
 */
- (void)fuzzyDetect:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 识别一个图像是否为美食图像
 *
 * @input image
 *            输入图片
 * @input cookie
 *            当imagePath为url时，需要的cookie信息
 * @input seq
 *            请求序列号，用于流水查询
 */
- (void)foodDetect:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 识别一个图像的标签信息,对图像分类。
 *
 * @input imagePath
 *            输入图片
 * @input cookie
 *            当imagePath为url时，需要的cookie信息
 * @input seq
 *            请求序列号，用于流水查询
 */
- (void)imageTag:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;
/*!
 * 识别一个图像是否为色情图像
 *
 * @input imagePath
 *            输入图片
 * @input cookie
 *            当imagePath为url时，需要的cookie信息
 * @input seq
 *            请求序列号，用于流水查询
 */
- (void)imagePorn:(id)image cookie:(NSString *)cookie seq:(NSString *)seq successBlock:(HttpRequestSuccessBlock)successBlock failureBlock:(HttpRequestFailBlock)failureBlock;





@end
