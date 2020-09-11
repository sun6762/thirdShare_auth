//
//  ZYTencentManager.swift
//  zhuanyu
//
//  Created by ruiyu on 2020/9/8.
//  Copyright © 2020 ruiyu. All rights reserved.
//

import UIKit

@objc
protocol WeiXinAuthDelegate: NSObjectProtocol{
    @objc optional func wxAuthSucceed(code: String?)
    @objc optional func wxAuthDenied()
    @objc optional func wxAuthCancel()
}

@objc
protocol QQAuthDelegate: NSObjectProtocol{
    func qqAuthSucceed(accessToken: String, openId: String)
    @objc optional func qqAuthFailure()
    @objc optional func qqAuthDisconnect()
}

class ZYTencentManager: NSObject {
    
    static let shared = ZYTencentManager()
    
    weak var delegate: WeiXinAuthDelegate?
    weak var qqDelegate: QQAuthDelegate?
    var tencentOAuth: TencentOAuth?
    
    private var authState: String?
}

// MARK: - Weixin -
extension ZYTencentManager {
    
    /// 发送微信授权请求
    /// - Parameters:
    ///   - controller: 当前界面的控制器对象
    ///   - authDelegate: 授权的代理回调
    ///   - completion: 授权结果的回调
    /// - Returns: nil
    func sendWxAuthRequest(with controller: UIViewController?, authDelegate: WeiXinAuthDelegate?, completion: ((Bool) -> ())?){
        checkWxInstalled()
        let req = SendAuthReq()
        req.scope = "snsapi_userinfo"
        req.state = "1235"
        authState = "1235"
        delegate = authDelegate
        guard let ctrl = controller else {
            return
        }
        WXApi.sendAuthReq(req, viewController: ctrl, delegate: self, completion: completion)
    }
    
    
    /// 微信登录成功后,根据 code 获取 accessToken, openId
    /// - Parameters:
    ///   - code: 微信登录成功后获取的 code
    ///   - appId: 微信 appId, 从微信官方平台获取
    ///   - appSecret: 微信 appSecret, 从微信官方平台获取
    ///   - completion: 成功或者失败之后的回调
    /// - Returns: nil
    func loadWeixinInfo(with code: String?, _ appId: String? = "", _ appSecret:String? = "", completion: ((_ accessToken: String, _ openId: String, _ errorString: String) -> ())? ){
        checkWxInstalled()
        guard let wxCode = code, !wxCode.isEmpty ,let url = URL.init(string: "https://api.weixin.qq.com/sns/oauth2/access_token?appid=wx86a21a793c26676e&secret=419d8ea2e5a880d655b9681dfd1b30cb&grant_type=authorization_code&code=\(code ?? "")") else{
            completion?("", "", "url 不正确")
            return
        }
        
        let str = try?String.init(contentsOf: url, encoding: .utf8)
        let data = str?.data(using: .utf8)
        DispatchQueue.main.async {
            if !(data?.isEmpty ?? true), let resp = data{
                guard let dict = try?JSONSerialization.jsonObject(with: resp, options: .mutableContainers) as? [String: Any], let accessToken = dict["access_token"] as? String, let openId = dict["openid"] as? String, !accessToken.isEmpty, !openId.isEmpty else{
                    completion?("", "", "token获取失败")
                    return
                }
                completion?(accessToken, openId, "")
            }else{
                completion?("", "", "token获取失败")
            }
        }
    }
    
    
    /// 微信分享: 网页分享
    /// - Parameters:
    ///   - urlString: 网页的链接
    ///   - title: 标题
    ///   - description: 描述
    ///   - thumbImage: 缩略图
    ///   - scene: 分享场景, 默认分享到聊天列表
    ///   - completion: 分享结果回调
    /// - Returns: nil
    func shareWxLink(with urlString: String, title: String, description: String, thumbImage: UIImage? = nil, scene:WXScene? = WXSceneSession, completion: ((Bool) -> ())?){
        checkWxInstalled()
        let webpageObject = WXWebpageObject.init()
        webpageObject.webpageUrl = urlString
        
        let message = WXMediaMessage.init()
        message.title = title
        message.description = description
        message.mediaTagName = "WECHAT_TAG_JUMP_SHOWRANK"
        message.mediaObject = webpageObject
        if let image = thumbImage {
            message.thumbData = image.pngData()
        }else{
            message.thumbData = UIImage.init(named: "wxLogoGreen")?.pngData()
        }
        
        let req = SendMessageToWXReq.init()
        req.message = message
        req.bText = false
        req.scene = Int32(scene!.rawValue)
        WXApi.send(req, completion: completion)
    }
    
    /// 微信分享: 分享文案
    /// - Parameters:
    ///   - text: 文字内容
    ///   - scene: 分享场景, default is WXSceneSession
    ///   - completion: 分享结束后的回调
    /// - Returns: nil
    func shareWxText(with text:String, scene:WXScene? = WXSceneSession, completion: ((Bool) -> ())?) {
        checkWxInstalled()
        let req = SendMessageToWXReq.init()
        req.bText = true
        req.text = text
        req.scene = Int32(scene!.rawValue)
        WXApi.send(req, completion: completion)
    }
    
    
    /// 微信分享: 分享单图
    /// - Parameters:
    ///   - image: 图片
    ///   - scene: 分享场景, default is WXSceneSession
    ///   - completion: 分享完成后的回调
    /// - Returns: nil
    func shareWxImage(with image:UIImage, scene:WXScene? = WXSceneSession, completion: ((Bool) -> ())?){
        checkWxInstalled()
        let req = SendMessageToWXReq.init()
        req.bText = false
        let imageObject = WXImageObject.init()
        guard let data = image.jpegData(compressionQuality: 0.7) else { return  }
        imageObject.imageData = data
        
        let message = WXMediaMessage.init()
        message.mediaObject = imageObject
        req.message = message 
        req.scene = Int32(scene!.rawValue)
        WXApi.send(req, completion: completion)
    }
    
}

extension ZYTencentManager: WXApiDelegate{
    func onReq(_ req: BaseReq) {
        
    }
    
    func onResp(_ resp: BaseResp) {
        if resp.isKind(of: SendAuthResp.self) {
            guard let response = resp as? SendAuthResp, response.state == authState else {
                delegate?.wxAuthDenied?()
                return
            }
            
            switch response.errCode {
            case WXSuccess.rawValue:
                delegate?.wxAuthSucceed?(code: response.code ?? "")
                
            case WXErrCodeAuthDeny.rawValue:
                delegate?.wxAuthDenied?()
                
            case WXErrCodeUserCancel.rawValue:
                delegate?.wxAuthCancel?()
                
            default:
                delegate?.wxAuthDenied?()
            }
            
        }else if resp.isKind(of: SendMessageToWXResp.self){
          
        }
    }
}

// MARK: - QQ -
extension ZYTencentManager {
    
    /// 打开 QQ 对应的会话
    /// - Parameters:
    ///   - qqNum: qq 群号/ qq 号
    ///   - isGroup: 是否打开群会话
    ///   - completion: 打开之后的回调
    /// - Returns: 是否能成功打开
    @discardableResult
    func openQQSession(with qqNum:String?, isGroup:Bool? = true, completion: ((Bool) -> ())? = nil) -> Bool{
        
        guard let numStr = qqNum, !numStr.isEmpty, let url = (isGroup ?? true) ? URL.init(string: "mqqapi://card/show_pslcard?src_type=internal&version=1&uin=\(numStr)&key=76d103dcf6e654ac6b6411cb5547dc7a&card_type=group&source=external"): URL.init(string: "mqq://im/chat?chat_type=wpa&uin=\(numStr)&version=1&src_type=web")  else { return false }
        if UIApplication.shared.canOpenURL(url){
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
        } else{
            ZSProgressHUD.showMessage("您还未安装QQ")
        }
        return true
    }
    
    
    /// 分享图片到 QQ 空间,  走写说说路径，是一个指定为图片类型的，当图片数组为空时，默认走文本写说说
    /// - Parameter image: 图片
    func shareQQZone(with image:UIImage?, title: String? = "") {
        var obj = QQApiObject()
        if let sharedImage = image, let imageData = sharedImage.jpegData(compressionQuality: 0.7)  {
            ZSProgressHUD.showMessage("图片生成失败")
            obj = QQApiImageArrayForQZoneObject.objectWithimageDataArray([imageData], title: (title ?? ""), extMap:  nil) as! QQApiObject
        } else{
            obj = QQApiImageArrayForQZoneObject.objectWithimageDataArray([], title: (title ?? ""), extMap: nil) as! QQApiObject
        }
        let req = SendMessageToQQReq.init(content: obj)
        DispatchQueue.main.async {
            _ = QQApiInterface.sendReq(toQZone: req)
        }
    }
    
    /// 分享文字到 QQ 好友. 纯文本不支持分享到 qq 空间
    /// - Parameter text: 文字内容
    /// - Returns: 发送内容到 QQ 的结果码
    @discardableResult
    func shareQQText(with text: String?) -> QQApiSendResultCode{
        checkInstalled()
        guard let str = text, let obj = QQApiTextObject.object(withText: str) as? QQApiObject, let req = SendMessageToQQReq.init(content: obj) else { return QQApiSendResultCode.EQQAPISENDFAILD}
         
        return QQApiInterface.send(req)
    }
    
    
    /// 分享图片给好友
    /// - Parameters:
    ///   - image: 图片
    ///   - title: 标题
    ///   - desc: 描述
    /// - Returns: 发送内容到 QQ 的结果码
    @discardableResult
    func shareQQImage(with image:UIImage?, title: String? = "", desc:String? = "") -> QQApiSendResultCode{
        checkInstalled()
        guard let shareImg = image, let imageData = shareImg.jpegData(compressionQuality: 0.7), let preImageData = shareImg.jpegData(compressionQuality: 0.2) else{
            return QQApiSendResultCode.EQQAPISENDFAILD
        }
        let obj = QQApiImageObject.init(data: imageData, previewImageData: preImageData, title: (title ?? ""), description: (desc ?? ""))
        let req = SendMessageToQQReq.init(content: obj)
        
        return QQApiInterface.send(req)
    }
    
    
    /// 上传多张图片
    /// - Parameters:
    ///   - imageArr: 图片数组
    ///   - title: 标题
    ///   - desc: 描述
    /// - Returns: 发送内容到 QQ 的结果码
    @discardableResult
    func shareQQMutileImage(with imageArr: [UIImage]?, title: String? = "", desc:String? = "") -> QQApiSendResultCode{
        checkInstalled()
        guard let shareImgs = imageArr, !shareImgs.isEmpty else{
            return QQApiSendResultCode.EQQAPISENDFAILD
        }
        
        var imageData: Data?
        var preImageData: Data?
        var imageDataArr = [Data]()
        for i in 0..<shareImgs.count{
            guard let data = shareImgs[i].jpegData(compressionQuality: 0.7) else {
                return QQApiSendResultCode.EQQAPISENDFAILD
            }
            imageDataArr.append(data)
            if i == 0{
                imageData = data
                preImageData = shareImgs[i].jpegData(compressionQuality: 0.2)
            }
        }
        
        let obj = QQApiImageObject.init(data: imageData, previewImageData: preImageData, title: (title ?? ""), description: (desc ?? ""))
        let req = SendMessageToQQReq.init(content: obj)
        
        return QQApiInterface.send(req)
    }
    
    
    /// qq 授权登录
    /// - Parameter appId: qq官方平台创建 app 时,获取的 appId
    func sendQQAuthReqest(appId: String) {
        let permissions = [kOPEN_PERMISSION_GET_USER_INFO,              kOPEN_PERMISSION_GET_SIMPLE_USER_INFO]
        tencentOAuth = TencentOAuth.init(appId: appId, andDelegate: self)
        tencentOAuth?.authorize(permissions)
    }
    
    
    /// qq 授权初始化,向 qq 进行注册; 这一步提前写入 AppDelegate 中 的 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) 方法中 ; 主要是用来帮助判断是否有登陆被发起，但是还没有过返回结果
    /// - Parameter appId: qq官方平台创建 app 时,获取的 appId
    func qqAuthInitialize(appId: String) {
        // 向 QQ 注册
        tencentOAuth = TencentOAuth.init(appId: appId, andDelegate: self)
        TencentOAuth.authorizeState()
    }
    
}

extension ZYTencentManager: TencentSessionDelegate{
    
    /// qq登录成功时的回调
    func tencentDidLogin() {
//        debugPrint(tencentOAuth?.accessToken, tencentOAuth?.openId)
        guard let accessToken = tencentOAuth?.accessToken, let openId = tencentOAuth?.openId  else { return  }
        qqDelegate?.qqAuthSucceed(accessToken: accessToken, openId: openId)
    }
    
    /// qq登录失败时的回调
    func tencentDidNotLogin(_ cancelled: Bool) {
        qqDelegate?.qqAuthFailure?()
    }
    
    /// qq登录时网络有问题的回调
    func tencentDidNotNetWork() {
        qqDelegate?.qqAuthDisconnect?()
    }
}


// MARK: - private -
extension ZYTencentManager {
    
    private func checkInstalled() {
        if !QQApiInterface.isQQInstalled() {return}
    }
    
    private func checkWxInstalled() {
        if !WXApi.isWXAppInstalled() {return}
    }
}


