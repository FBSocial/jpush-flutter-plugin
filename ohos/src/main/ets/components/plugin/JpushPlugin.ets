import {
  Any,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import { JPushInterface } from '@jg/push';
import { abilityAccessCtrl, bundleManager, common, Permissions, Want, wantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { HashMap } from '@kit.ArkTS';

export default class JpushPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  public TAG = "fb-ohos-JpushPlugin";
  private sequence: number = 0;
  private packageName = "com.idreamsky.fanbook";
  //回调map
  public callbackMap: HashMap<number, MethodResult> = new HashMap();

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
      || method == "applyPushAuthority" || method == "clearNotification" || method == "getBadge") {
      //这些方法，极光sdk未提供，直接返回成功
      result.success(null)
    } else if (method == "getRegistrationID") {
      let rid = JPushInterface.getRegistrationId()
      result.success(rid)
      console.log(this.TAG, "registrationId: " + rid);
    } else if (method == "setBadge") {
      let badge = call.argument("badge") as number;
      JPushInterface.setBadgeNumber(badge)
      result.success(null)
    } else if (method == "cleanTags") {
      JPushInterface.cleanTags(this.sequence++)
      result.success(null)
    } else if (method == "deleteTags") {
      let tags = call.args as string[];
      JPushInterface.deleteTags(this.sequence++, tags)
      result.success(null)
      console.log(this.TAG, "tags: " + tags.join("-"));
    } else if (method == "setAlias") {
      let seq = this.sequence++;
      let alias = call.args as string;
      this.callbackMap.set(seq, result);
      JPushInterface.setAlias(seq, alias);
      console.log(this.TAG, "setAlias: " + alias + " seq:" + seq);
    } else if (method == "isNotificationEnabled") {
      //是否打开通知开关
      let isEnabled = notificationManager.isNotificationEnabledSync();
      let map: HashMap<string, boolean> = new HashMap();
      map.set("isEnabled", isEnabled);
      result.success(map)
      console.log(this.TAG, "isNotificationEnabled -> isEnabled: " + isEnabled);
    } else if (method == "openSettingsForNotification") {
      let wantInfo: Want = {
        deviceId: '', // deviceId为空表示本设备
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'systemui_notification_settings', //应用的通知设置入口
        parameters: {
          pushParams: {
            bundleName: this.packageName
          }
        }
      }
      let context = getContext(this) as common.UIAbilityContext
      context.startAbility(wantInfo)
      result.success(null)
    } else if (method == "sendLocalNotification") {
      this.sendLocalPush(call)
      result.success(null)
    } else if (method == "clearAllNotifications") {
      notificationManager.cancelAll()
      result.success(null)
    } else {
      result.notImplemented()
    }
    console.log(this.TAG, "onMethodCall: " + method + " - end")
  }

  /**
   * 发本地push
   */
  async sendLocalPush(call: MethodCall): Promise<void> {
    let map = call.args as HashMap<string, Object>;
    let id: number = map.get('id') as number;
    let title = map.get('title') as string;
    let content = map.get('content') as string;
    let extra = map.get('extra') as HashMap<string, string>;
    let record: Record<string, string> = {};
    //本地在线push的标记
    record['jpush_local'] = '1'
    for (let key of extra.keys()) {
      record[key] = extra.get(key)
    }
    console.log(this.TAG, "sendLocalPush -- title: " + title);
    let wantAgentInfo: wantAgent.WantAgentInfo = {
      wants: [
        {
          bundleName: this.packageName,
          abilityName: "EntryAbility",
          parameters: record,
        }
      ],
      operationType: wantAgent.OperationType.START_ABILITIES,
      requestCode: 1,
    }
    const wantAgentObj = await wantAgent.getWantAgent(wantAgentInfo)
    let notificationRequest: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT, // 普通文本类型通知
        normal: {
          title: title,
          text: content
        },
      },
      deliveryTime: new Date().getTime(),
      showDeliveryTime: true,
      wantAgent: wantAgentObj,
      notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION
    };
    notificationManager.publish(notificationRequest);
  }

  /**
   * 回调flutter的方法
   */
  callbackFlutter(method: string, data: Any) {
    console.log(this.TAG, "callbackFlutter method:" + method + " data:" + data)
    this.channel?.invokeMethod(method, data)
  }

  /**
   ** 收到极光回调后，再返回结果给flutter
   ** 极光回调逻辑在主工程的JPushCallBackMsg中
   */
  onCallbackResult(type: number, seq: number, code: number, dataMap?: HashMap<string, Any>) {
    console.log(this.TAG, "onCallbackResult type:" + type + " seq:" + seq + " code:" + code)
    if (!this.callbackMap.hasKey(seq)) {
      console.log(this.TAG, "onCallbackResult no-key seq:" + seq)
      return;
    }
    if (type == 0) {
      let result = this.callbackMap.get(seq)
      if (code == 0) {
        let map: HashMap<string, string> = new HashMap();
        result.success(map);
      } else {
        result.error(code.toString(), '', '');
      }
      this.callbackMap.remove(seq)
    }
  }
}