import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { JPushInterface } from '@jg/push';
import { abilityAccessCtrl, bundleManager, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** JpushPlugin **/
export default class JpushPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  public TAG = "JpushPlugin";
  private sequence: number = 0;

  constructor() {
  }

  getUniqueClassName(): string {
    return "JpushPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "jpush");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    let method = call.method
    console.log(this.TAG, "onMethodCall: " + method);
    if (method == "getPlatformVersion") {
      result.success("OpenHarmony ^ ^ ")
    } else if (method == "setAuth" || method == "setup" || method == "getLaunchAppNotification"
      || method == "applyPushAuthority" || method == "sendLocalNotification" || method == "clearAllNotifications"
      || method == "clearNotification" || method == "getBadge") {
      //这些方法，极光sdk未提供，直接返回成功
      result.success(null)
    } else if (method == "getRegistrationID") {
      // let context = getContext(this) as common.UIAbilityContext
      let rid = JPushInterface.getRegistrationId()
      result.success(rid)
      console.log(this.TAG, "rid: " + rid);
    } else if (method == "setBadge") {
      let badge = call.argument("badge") as number;
      JPushInterface.setBadgeNumber(badge)
      result.success(null)
      console.log(this.TAG, "badge: " + badge);
    } else if (method == "cleanTags") {
      JPushInterface.cleanTags(this.sequence++)
      result.success(null)
    } else if (method == "deleteTags") {
      let tags = call.args as string[];
      JPushInterface.deleteTags(this.sequence++, tags)
      result.success(null)
      console.log(this.TAG, "tags: " + tags.join("-"));
    } else if (method == "setAlias") {
      let alias = call.args as string;
      JPushInterface.setAlias(this.sequence++, alias)
      result.success(null)
      console.log(this.TAG, "alias: " + alias);
    } else if (method == "isNotificationEnabled") {
      //是否打开通知开关
      let isEnabled = this.checkPushPermission()
      result.success(isEnabled)
      console.log(this.TAG, "isNotificationEnabled isEnabled: " + isEnabled);
    } else if (method == "openSettingsForNotification") {
      //打开通知设置
      result.success(null)
    } else {
      result.notImplemented()
    }
    console.log(this.TAG, "onMethodCall: " + method + " - end");
  }

  checkAccessToken(permission: Permissions): abilityAccessCtrl.GrantStatus {
    let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    let grantStatus: abilityAccessCtrl.GrantStatus = abilityAccessCtrl.GrantStatus.PERMISSION_DENIED;
    // 获取应用程序的accessTokenID
    let tokenId: number = 0;
    try {
      let bundleInfo = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION)
      // let bundleInfo =
      //   await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      let appInfo = bundleInfo.appInfo;
      tokenId = appInfo.accessTokenId;
    } catch (err) {
      console.error(this.TAG, `checkAccessToken error：${err.code}, ${err.message}`);
    }

    // 校验应用是否被授予权限
    try {
      grantStatus = atManager.verifyAccessTokenSync(tokenId, permission);
    } catch (err) {
      console.error(this.TAG, `verifyAccessTokenSync error：${err.code}, ${err.message}`);
    }
    return grantStatus;
  }

  //检查是否打开通知开关
  checkPushPermission(): boolean {
    const permissions: Array<Permissions> = ['ohos.permission.ACCESS_NOTIFICATION_POLICY'];
    let grantStatus = this.checkAccessToken(permissions[0]);
    return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
  }
}