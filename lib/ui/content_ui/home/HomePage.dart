import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:com.urbaevent/model/ResponseAuthRole.dart';
import 'package:com.urbaevent/model/ResponseNotifications.dart';
import 'package:com.urbaevent/utils/QrScannerOverlayShape.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:com.urbaevent/adapter_view/CurrentEvents.dart';
import 'package:com.urbaevent/adapter_view/EBadge.dart';
import 'package:com.urbaevent/adapter_view/MyContact.dart';
import 'package:com.urbaevent/adapter_view/MyEvents.dart';
import 'package:com.urbaevent/adapter_view/UpcomingEvent.dart';
import 'package:com.urbaevent/dialogs/Progressbar.dart';
import 'package:com.urbaevent/model/ResponseContactDetails.dart';
import 'package:com.urbaevent/model/ResponseContactList.dart';
import 'package:com.urbaevent/model/ResponseScanContact.dart';
import 'package:com.urbaevent/model/common/ResponseError.dart';
import 'package:com.urbaevent/model/events/ResponseEbadges.dart';

import 'package:com.urbaevent/model/events/ResponseEvents.dart';
import 'package:com.urbaevent/model/common/ResponseUser.dart';
import 'package:com.urbaevent/model/events/ResponseMyEvents.dart';
import 'package:com.urbaevent/ui/auth/SignIn.dart';
import 'package:com.urbaevent/ui/auth/SignUp.dart';
import 'package:com.urbaevent/ui/content_ui/home/sub_views/EBadgeDetails.dart';
import 'package:com.urbaevent/ui/content_ui/Event/EventDetails.dart';
import 'package:com.urbaevent/ui/content_ui/home/NotificationList.dart';
import 'package:com.urbaevent/ui/content_ui/home/sub_views/Profile.dart';
import 'package:com.urbaevent/ui/content_ui/home/sub_views/ProfileInformation.dart';
import 'package:com.urbaevent/utils/Const.dart';
import 'package:com.urbaevent/utils/PageVisibilityObserver.dart';
import 'package:com.urbaevent/utils/Preference.dart';
import 'package:com.urbaevent/utils/Urls.dart';
import 'package:com.urbaevent/utils/ThemeColor.dart';
import 'package:com.urbaevent/utils/Utils.dart';
import 'package:com.urbaevent/widgets/CustomBottomBar.dart';
import 'package:com.urbaevent/widgets/CustomToolbar.dart';
import 'package:com.urbaevent/widgets/HalfImageVisible.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_mobile_vision/qr_camera.dart';
import 'package:vibration/vibration.dart';
import 'package:visibility_detector/visibility_detector.dart';

class HomePage extends StatefulWidget {
  final int setUIMode;

  HomePage(this.setUIMode);

  @override
  State<StatefulWidget> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  bool showSearchView = false;
  bool isLoggedIn = false;
  int uiMode = 0;
  bool loader = false;
  String scanResult = "";
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  TextEditingController textController = TextEditingController();

  late ResponseEvents responseEvents;
  ResponseMyEvents? userResponseEvents;
  List<EventItem> filteredEvents = [];
  ResponseUser? _responseUser;
  ResponseEbadges? responseEbadges;
  ResponseScanContact? responseScanContact;
  ResponseContactList? responseContactList;
  List<ContactItem>? contactItemList;
  ResponseContactDetails? responseContactDetails;
  ResponseNotifications? responseNotifications;

  bool getEventsInit = false;
  bool getEventsFailed = false;
  late PageVisibilityObserver _pageVisibilityObserver;
  bool _isVisible = true;
  int ebadgeItemPosition = -1;
  AudioPlayer? audioPlayer;
  bool isInit = false;
  int lastReadIndex = -1;
  String? qr;
  bool camState = true;
  bool dirState = false;

  void handleCallback(int val) {
    setState(() {
      loader = false;

      if (isLoggedIn) {
        if (val == Const.homeUI) {
          showSearchView = false;
        }
        if (val == Const.profileUI) {
          showSearchView = false;
          getUserDetails();
        }
        if (val == Const.myContactsUI) {
          showSearchView = false;
          getContactList();
        }
        if (val == Const.scanUI) {
          scanResult = "";
        }
        uiMode = val;
      } else {
        if (val == Const.homeUI) {
          showSearchView = false;
          getEventList();
          getUserDetails();
          uiMode = val;
        } else {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => SignIn(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0); // Slide from right
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
            ),
          );
        }
      }
    });
  }

  void handleEBadgeDetails(int val) {
    setState(() {
      ebadgeItemPosition = val;
      uiMode = Const.eBadgeDetailsUI;
    });
  }

  void handleMyContactDetails(int val) {
    getContactDetails(contactItemList![val].users![0].id!);
  }

  void handleEventDetailsCallback(int val) {
    setState(() {
      bool myEvent = false;
      int confirmed = Const.eventConfirmationPending;
      String type = "visitor";
      type = responseEvents.data[val].type ?? "visitor";
      if (userResponseEvents != null && getEventsInit && isLoggedIn) {
        for (int j = 0; j < userResponseEvents!.data.length; j++) {
          if (responseEvents.data[val].id ==
              userResponseEvents!.data[j].event.id) {
            responseEvents.data[val].registrationType =
                userResponseEvents!.data[j].type;
            Const.registrationId = userResponseEvents!.data[j].id;
            myEvent = true;
            if (userResponseEvents!.data[j].confirmed == null) {
              confirmed = Const.eventConfirmationPending;
            } else if (userResponseEvents!.data[j].confirmed != null &&
                userResponseEvents!.data[j].confirmed!) {
              confirmed = Const.eventConfirmed;
            } else if (userResponseEvents!.data[j].confirmed != null &&
                !userResponseEvents!.data[j].confirmed!) {
              confirmed = Const.eventConfirmationRejected;
            }
            break;
          }
        }
      }
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => EventDetails(
              data: responseEvents.data[val],
              isRegisteredForEvent: myEvent,
              confirmed: confirmed,
              type: type),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0); // Slide from right
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        ),
      );
    });
  }

  void handleMyEventDetailsCallback(int val, int confirmed, String type) {
    if (getEventsInit) {
      String regType = "visitor";
      for (int j = 0; j < userResponseEvents!.data.length; j++) {
        if (val == userResponseEvents!.data[j].event.id) {
          Const.registrationId = userResponseEvents!.data[j].id;
          regType = userResponseEvents!.data[j].type.toString();
        }
      }
      for (int i = 0; i < responseEvents.data.length; i++) {
        if (val == responseEvents.data[i].id) {
          type = responseEvents.data[i].type ?? "visitor";
          responseEvents.data[i].registrationType = regType;

          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  EventDetails(
                      data: responseEvents.data[i],
                      isRegisteredForEvent: true,
                      confirmed: confirmed,
                      type: type),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0); // Slide from right
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
            ),
          );
          break;
        }
      }
    }
  }

  void handleProfileCallbacks(int val) {
    setState(() {
      switch (val) {
        case 0:
          break;

        case 1:
          String stringPicUrl = "";
          if (_responseUser!.avatar == null) {
            stringPicUrl = Urls.imageURL;
          } else {
            stringPicUrl = Urls.imageURL + _responseUser!.avatar!.url;
          }

          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ProfileInformation(
                      title: "",
                      isMine: true,
                      avatar: stringPicUrl,
                      name: _responseUser!.name,
                      company: _responseUser!.company,
                      businessIndustry: _responseUser!.businessSector,
                      email: _responseUser!.email,
                      phoneNumber: _responseUser!.phone,
                      isUser: true),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0); // Slide from right
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
            ),
          );
          break;

        case 3:
          _showLogoutDialog(context);
          break;
      }
    });
  }

  void onBackCallBack() {
    setState(() {
      onBackOptions();
    });
  }

  void onBackOptions() {
    if (uiMode == Const.eBadgeDetailsUI) {
      uiMode = Const.eBadgesUI;
    } else if (uiMode == Const.contactDetailsUI) {
      uiMode = Const.myContactsUI;
    } else if (uiMode == Const.contactDetailsUI) {
      uiMode = Const.eBadgesUI;
      getEbadgesList();
    } else {
      uiMode = Const.homeUI;
      getEventList();
    }
  }

  Future<void> clearAppPreferences() async {
    Preference preference = await Preference.getInstance();
    preference.clearAppPreferences();
  }

  Future<void> getEventList() async {
    setState(() {
      loader = true;
    });
    final url = Uri.parse(Urls.baseURL + Urls.eventList);

    final response = await http.get(url);
    final parsedJson = jsonDecode(response.body);

    if (response.statusCode == HttpStatus.ok) {
      print('Response Login' + response.body);
      responseEvents = ResponseEvents.fromJson(parsedJson);
      filteredEvents = ResponseEvents.fromJson(parsedJson).data;
      getEventsInit = true;
    } else {
      debugPrint('Response Error' + response.body);
      final error = ResponseError.fromJson(parsedJson);
      Utils.showToast(error.error.message);
      getEventsFailed = true;
    }

    setState(() {
      getUserDetails();
      loader = false;
    });
  }

  void filterItems(String query) {
    setState(() {
      // If the query is empty, display the initial list
      if (query.isEmpty) {
        filteredEvents.clear();
        filteredEvents.addAll(responseEvents.data);
      } else {
        // Otherwise, filter the items based on the query
        filteredEvents = responseEvents.data
            .where(
                (item) => item.name.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          title: Text(
            Intl.message("logout", name: "logout"),
            style: GoogleFonts.roboto(
                color: Colors.black,
                fontStyle: FontStyle.normal,
                fontSize: 16,
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          content: Text(Intl.message("logout_msg", name: "logout_msg"),
              style: GoogleFonts.roboto(
                  color: Colors.black,
                  fontStyle: FontStyle.normal,
                  fontSize: 16,
                  fontWeight: FontWeight.w400),
              textAlign: TextAlign.center),
          actions: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    Intl.message("cancel", name: "cancel"),
                    style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontStyle: FontStyle.normal,
                        fontSize: 12,
                        fontWeight: FontWeight.w400),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(217, 217, 217, 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
                SizedBox(
                  width: 25,
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    setState(() {
                      clearAppPreferences();
                      uiMode = Const.homeUI;
                      isLoggedIn = false;
                    });
                  },
                  child: Text(
                    Intl.message("yes", name: "yes"),
                    style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontStyle: FontStyle.normal,
                        fontSize: 12,
                        fontWeight: FontWeight.w400),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ThemeColor.themeOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                  ),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  Future<void> vibrateOnce() async {
    var available = await Vibration.hasVibrator();
    if (available != null) {
      Vibration.vibrate(duration: 500);
    }
  }

  Future<void> getAuthRole() async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();

    if (jwtToken.isNotEmpty) {
      setState(() {
        loader = true;
      });

      final url = Uri.parse(Urls.baseURL + Urls.authRole);
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      final parsedJson = jsonDecode(response.body);

      if (response.statusCode == HttpStatus.ok) {
        print('Response Auth' + response.body);
        preference.saveAuthRole(ResponseAuthRole.fromJson(parsedJson));
      } else if (response.statusCode == HttpStatus.unauthorized) {
        setState(() {
          preference.clearAppPreferences();
        });
      } else {
        print('Response Error' + response.body);
        final error = ResponseError.fromJson(parsedJson);
        Utils.showToast(error.error.message);
      }
    } else {
      setState(() {
        loader = false;
      });
    }
  }

  Future<void> getNotifications() async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();

    if (jwtToken.isNotEmpty) {
      if (preference.getAuthRole() != null &&
          preference.getAuthRole()!.lastNotificationIndex != null) {
        lastReadIndex = preference.getAuthRole()!.lastNotificationIndex!;
        print('Last Read Index: $lastReadIndex');
      }

      final url = Uri.parse(Urls.baseURL + Urls.notificationList);
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      final parsedJson = jsonDecode(response.body);

      if (response.statusCode == HttpStatus.ok) {
        print('Response Notifications' + response.body);
        setState(() {
          loader = false;
          responseNotifications = ResponseNotifications.fromJson(parsedJson);
          int unreadCount = 0;
          if (lastReadIndex > 0) {
            unreadCount = responseNotifications!.data!.length - lastReadIndex;
          }
          if (unreadCount > 0) {
            Utils.notificationCount = unreadCount;
          } else {
            Utils.notificationCount = 0;
          }
        });
      } else if (response.statusCode == HttpStatus.unauthorized) {
        setState(() {
          loader = false;
          preference.clearAppPreferences();
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomePage(Const.homeUI)),
            (route) => false,
          );
        });
      } else {
        setState(() {
          loader = false;
        });
        print('Response Error' + response.body);
        final error = ResponseError.fromJson(parsedJson);
        Utils.showToast(error.error.message);
      }
    } else {
      setState(() {
        loader = false;
      });
    }
  }

  Future<void> getUserDetails() async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();

    if (jwtToken.isNotEmpty) {
      setState(() {
        isLoggedIn = true;
      });
      String os;
      final info = await PackageInfo.fromPlatform();
      if (Platform.isAndroid) {
        os = "android";
      } else {
        os = "ios";
      }

      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? fcmToken = await messaging.getToken();

      final url = Uri.parse(Urls.baseURL + Urls.userDetails);

      // Add parameters to the URL
      final Map<String, String> params = {
        'os': os,
        'appVersion': info.version,
        'fcm': fcmToken ?? ""
      };
      final Uri uriWithParams = url.replace(queryParameters: params);
      final response = await http.get(
        uriWithParams,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      final parsedJson = jsonDecode(response.body);

      if (response.statusCode == HttpStatus.ok) {
        setState(() {
          _responseUser = ResponseUser.fromJson(parsedJson);
        });
      } else if (response.statusCode == HttpStatus.unauthorized) {
        setState(() {
          preference.clearAppPreferences();
          isLoggedIn = false;
          uiMode = Const.homeUI;
        });
      } else {
        print('Response Error' + response.body);
        final error = ResponseError.fromJson(parsedJson);
        Utils.showToast(error.error.message);
      }
    } else {
      setState(() {
        isLoggedIn = false;
      });
    }

    setState(() {
      getAuthRole();
      isInit = true;
    });

    if (_responseUser!.emailOTPConfirmed == true && jwtToken.isNotEmpty) {
      getUserEventList(jwtToken, preference.getLoginDetails()!.user.id);
      getEbadgesList();
    } else {
      clearAppPreferences();
      setState(() {
        uiMode = Const.homeUI;
        isLoggedIn = false;
      });
    }
  }

  Future<void> getContactList() async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();

    if (preference.getAuthRoleAgent() == null) {
      if (jwtToken.isNotEmpty) {
        setState(() {
          isLoggedIn = true;
        });

        final url = Uri.parse(Urls.baseURL +
            Urls.contactList +
            preference.getUserId().toString() +
            Urls.contactListFilter1 +
            preference.getUserId().toString() +
            Urls.contactListFilter2);
        final response = await http.get(
          url,
          headers: {'Authorization': 'Bearer $jwtToken'},
        );

        final parsedJson = jsonDecode(response.body);

        if (response.statusCode == HttpStatus.ok) {
          setState(() {
            responseContactList = ResponseContactList.fromJson(parsedJson);
            contactItemList = [];
            for (int i = 0; i < responseContactList!.data!.length; i++) {
              if (responseContactList!.data![i].users != null &&
                  responseContactList!.data![i].users!.isNotEmpty) {
                contactItemList!.add(responseContactList!.data![i]);
              }
            }
          });
        } else if (response.statusCode == HttpStatus.unauthorized) {
          setState(() {
            preference.clearAppPreferences();
            isLoggedIn = false;
            uiMode = Const.homeUI;
          });
        } else {
          print('Response ContactList' + response.body);
          final error = ResponseError.fromJson(parsedJson);
          Utils.showToast(error.error.message);
        }
      }
    }
  }

  Future<void> getUserEventList(String token, int userId) async {
    setState(() {
      loader = true;
    });
    final url = Uri.parse(Urls.baseURL +
        Urls.userEventList +
        userId.toString() +
        Urls.userEventListFilter);
    print('URL' + url.toString());
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    final parsedJson = jsonDecode(response.body);
    if (response.statusCode == HttpStatus.ok) {
      print('Response user events' + response.body);
      setState(() {
        userResponseEvents = ResponseMyEvents.fromJson(parsedJson);
      });
    } else if (response.statusCode == HttpStatus.unauthorized) {
      Preference preference = await Preference.getInstance();
      setState(() {
        preference.clearAppPreferences();
        isLoggedIn = false;
        uiMode = Const.homeUI;
      });
    } else {
      print('Response user events error' + response.body);
      final error = ResponseError.fromJson(parsedJson);
      Utils.showToast(error.error.message);
    }

    setState(() {
      loader = false;
    });
  }

  Future<void> addUserToContact(List<String> strResult) async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();

    if (jwtToken.isNotEmpty) {
      setState(() {
        loader = true;
      });
      final jsonData = {
        "data": {
          "userScannerId": preference.getUserId(),
          "registrationId": strResult[0],
        }
      };

      final url = Uri.parse(Urls.baseURL + Urls.scans);
      print('URL' + url.toString());
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(jsonData),
      );
      final parsedJson = jsonDecode(response.body);
      if (response.statusCode == HttpStatus.ok) {
        print('Response add contact' + response.body);
        setState(() {
          responseScanContact = ResponseScanContact.fromJson(parsedJson);
          Utils.showToast(Intl.message("contact_added_successfully",
              name: "contact_added_successfully"));
          uiMode = Const.myContactsUI;
          getContactList();
        });
      } else if (response.statusCode == HttpStatus.unauthorized) {
        setState(() {
          preference.clearAppPreferences();
          isLoggedIn = false;
          uiMode = Const.homeUI;
        });
      } else {
        print('Response add contact error' + response.body);
        final error = ResponseError.fromJson(parsedJson);
        Utils.showToast(error.error.message);
        Timer(Duration(seconds: 3), () {
          scanResult = "";
        });
      }

      setState(() {
        loader = false;
      });
    }
  }

  Future<void> getContactDetails(int userID) async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();

    if (jwtToken.isNotEmpty) {
      setState(() {
        loader = true;
      });

      final url = Uri.parse(Urls.baseURL +
          Urls.contactDetails +
          userID.toString() +
          Urls.contactDetailsFilter +
          userID.toString());
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $jwtToken',
          'Content-Type': 'application/json',
        },
      );
      final parsedJson = jsonDecode(response.body);
      if (response.statusCode == HttpStatus.ok) {
        setState(() {
          responseContactDetails = ResponseContactDetails.fromJson(parsedJson);

          String stringPicUrl = "";
          if (responseContactDetails!.avatar == null) {
            stringPicUrl = Urls.imageURL;
          } else {
            stringPicUrl = Urls.imageURL + responseContactDetails!.avatar!.url!;
          }

          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  ProfileInformation(
                      title: "",
                      isMine: false,
                      avatar: stringPicUrl,
                      name: responseContactDetails!.name ?? " ",
                      company: responseContactDetails!.company ?? " ",
                      businessIndustry:
                          responseContactDetails!.businessSector ?? " ",
                      email: responseContactDetails!.email ?? " ",
                      phoneNumber: responseContactDetails!.phone ?? " ",
                      isUser: true),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0); // Slide from right
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
            ),
          );
        });
      } else if (response.statusCode == HttpStatus.unauthorized) {
        setState(() {
          preference.clearAppPreferences();
          isLoggedIn = false;
          uiMode = Const.homeUI;
        });
      } else {
        print('Response contact details error' + response.body);
        final error = ResponseError.fromJson(parsedJson);
        Utils.showToast(error.error.message);
      }

      setState(() {
        loader = false;
      });
    }
  }

  Future<void> getUIStates() async {
    Preference preference = await Preference.getInstance();
    if (preference.getToken().isNotEmpty) {
      uiMode = widget.setUIMode;
    } else {
      if (widget.setUIMode == 0) {
        uiMode = widget.setUIMode;
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SignIn()),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pageVisibilityObserver =
        PageVisibilityObserver(_handlePageVisibilityChange);
    WidgetsBinding.instance.addObserver(_pageVisibilityObserver);
    getUIStates();
    getEventList();
  }

  Future<void> getEbadgesList() async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();

    if (jwtToken.isNotEmpty) {
      final url = Uri.parse(Urls.baseURL +
          Urls.ebadgesList +
          preference.getLoginDetails()!.user.id.toString() +
          Urls.ebadgesListFilter);
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      final parsedJson = jsonDecode(response.body);

      if (response.statusCode == HttpStatus.ok) {
        setState(() {
          responseEbadges = ResponseEbadges.fromJson(parsedJson);
        });
      } else if (response.statusCode == HttpStatus.unauthorized) {
        setState(() {
          preference.clearAppPreferences();
          isLoggedIn = false;
          uiMode = Const.homeUI;
        });
      } else {
        print('Response Error' + response.body);
        final error = ResponseError.fromJson(parsedJson);
        Utils.showToast(error.error.message);
      }

      getContactList();
    }
  }

  void _handlePageVisibilityChange(bool isVisible) {
    setState(() {
      _isVisible = isVisible;
      if (_isVisible) {
        print('onResume');
      } else {
        print('onPause');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_pageVisibilityObserver);
    super.dispose();
  }

  double _calculateListViewHeight(int itemCount) {
    const listItemHeight = 100.0; // Example height of a ListTile
    const listPadding = 16.0; // Example padding between items
    return itemCount * (listItemHeight + listPadding);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UrbaEvent',
      debugShowCheckedModeBanner: false,
      home: _buildHomeContent(),
    );

  }

  Widget _buildHomeContent() {
    Future<bool> _onBackPressedOveRiding() async {
      if (uiMode == Const.homeUI) {
        return true;
      } else {
        setState(() {
          onBackOptions();
        });
      }
      return false;
    }

    return WillPopScope(
      onWillPop: _onBackPressedOveRiding,
      child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: VisibilityDetector(
            key: Key("homePage"),
            onVisibilityChanged: (VisibilityInfo info) {
              getUserDetails();
              getEventList();
            },
            child: Stack(
              children: [
                Container(color: ThemeColor.bgColor),
                if (uiMode == Const.homeUI || uiMode == Const.searchEventUI)
                  HalfImageVisible(),
                Column(
                  children: [
                    //Toolbar
                    if (uiMode == Const.homeUI || uiMode == Const.searchEventUI)
                      SizedBox(
                        height: 22,
                      ),
                    if (uiMode == Const.searchEventUI && isLoggedIn)
                      SizedBox(
                        height: 18,
                      ),
                    if (uiMode == Const.searchEventUI && !isLoggedIn)
                      SizedBox(
                        height: 30,
                      ),
                    if (uiMode == Const.homeUI || uiMode == Const.searchEventUI)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 16,
                          ),
                          if (!showSearchView)
                            Expanded(
                                flex: 1,
                                child: Container(
                                  alignment: Alignment.centerLeft,
                                  child: Image.asset(
                                    'assets/app_logo.png',
                                    width: 130,
                                    height: 90,
                                  ),
                                )),
                          Align(
                            alignment: Alignment.centerRight,
                            // Align the image to the right
                            child: Container(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (!isLoggedIn && !showSearchView)
                                    SizedBox(
                                      width: 40,
                                    ),
                                  if (!showSearchView)
                                    IconButton(
                                      iconSize: 50,
                                      icon: SvgPicture.asset(
                                        'assets/ic_search.svg',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.fitHeight,
                                      ),
                                      // Replace with your image asset path
                                      onPressed: () {
                                        setState(() {
                                          setState(() {
                                            showSearchView = true;
                                            uiMode = Const.searchEventUI;
                                          });
                                        });
                                      },
                                    ),
                                  if (showSearchView)
                                    LayoutBuilder(builder:
                                        (BuildContext context,
                                            BoxConstraints constraints) {
                                      int widthDifference = 0;

                                      if (isLoggedIn) {
                                        widthDifference = 82;
                                      } else {
                                        widthDifference = 40;
                                      }

                                      return Container(
                                        height: 40,
                                        width:
                                            MediaQuery.of(context).size.width -
                                                widthDifference,
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.all(
                                              Radius.circular(30.0),
                                            )),
                                        child: Stack(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                IconButton(
                                                  iconSize: 20,
                                                  icon: SvgPicture.asset(
                                                    'assets/ic_search_clear.svg',
                                                    width: 20,
                                                    height: 20,
                                                  ),
                                                  // Replace with your image asset path
                                                  onPressed: () {},
                                                ),
                                                Expanded(
                                                  child: Center(
                                                    child: TextField(
                                                      controller:
                                                          textController,
                                                      onChanged: filterItems,
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: Intl.message(
                                                            "search",
                                                            name: "search"),
                                                        hintStyle: TextStyle(
                                                            color:
                                                                Color.fromRGBO(
                                                                    132,
                                                                    130,
                                                                    130,
                                                                    1)),
                                                        border:
                                                            InputBorder.none,
                                                      ),
                                                      style: GoogleFonts.roboto(
                                                          fontSize: 18.0,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color: Color.fromRGBO(
                                                              0, 0, 0, 1.0)),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  iconSize: 30,
                                                  icon: SvgPicture.asset(
                                                    'assets/ic_close_clear_.svg',
                                                    width: 30,
                                                    height: 30,
                                                  ),
                                                  // Replace with your image asset path
                                                  onPressed: () {
                                                    setState(() {
                                                      showSearchView = false;
                                                      uiMode = Const.homeUI;
                                                    });
                                                  },
                                                )
                                              ],
                                            )
                                          ],
                                        ),
                                      );
                                    }),
                                  if (isLoggedIn)
                                    if (Utils.notificationCount != -1)
                                      IconButton(
                                        iconSize: 40,
                                        icon: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 40.0,
                                              // Adjust the size as needed
                                              height: 40.0,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                              ),
                                            ),
                                            SvgPicture.asset(
                                              'assets/ic_noti.svg',
                                              width: 20,
                                              height: 20,
                                              fit: BoxFit.cover,
                                            ),
                                            if (Utils.notificationCount > 0)
                                              Positioned(
                                                top: 4.0,
                                                // Adjust the top and right values as needed
                                                right: 6.0,
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  // Adjust the width and height as needed
                                                  height: 18.0,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color:
                                                        ThemeColor.colorAccent,
                                                  ),
                                                  child: Center(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4.0),
                                                      child: Text(
                                                        Utils.notificationCount
                                                            .toString(),
                                                        // Text inside the badge
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        // Replace with your image asset path
                                        onPressed: () {
                                          setState(() {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder: (context,
                                                        animation,
                                                        secondaryAnimation) =>
                                                    NotificationList(),
                                                transitionsBuilder: (context,
                                                    animation,
                                                    secondaryAnimation,
                                                    child) {
                                                  const begin = Offset(1.0,
                                                      0.0); // Slide from right
                                                  const end = Offset.zero;
                                                  const curve =
                                                      Curves.easeInOut;
                                                  var tween = Tween(
                                                          begin: begin,
                                                          end: end)
                                                      .chain(CurveTween(
                                                          curve: curve));
                                                  var offsetAnimation =
                                                      animation.drive(tween);
                                                  return SlideTransition(
                                                      position: offsetAnimation,
                                                      child: child);
                                                },
                                              ),
                                            );
                                          });
                                        },
                                      )
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 10,
                          ),
                        ],
                      ),
                    if (uiMode == Const.searchEventUI)
                      SizedBox(
                        height: 20,
                      ),
                    if (uiMode == Const.myContactsUI)
                      CustomToolbar(
                          Intl.message("my_contacts", name: "my_contacts"),
                          onBackCallBack,
                          Utils.notificationCount,
                          false),
                    if (uiMode == Const.scanUI)
                      Container(
                        alignment: Alignment.center,
                        height: 130,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 30.0, right: 30, bottom: 20, top: 40),
                            child: Text(
                              Intl.message("header_scan", name: "header_scan"),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.roboto(
                                  color: ThemeColor.textPrimary,
                                  fontStyle: FontStyle.normal,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400),
                            ),
                          ),
                        ),
                      ),
                    if (uiMode == Const.eBadgesUI)
                      CustomToolbar(Intl.message("ebadges", name: "ebadges"),
                          onBackCallBack, Utils.notificationCount, false),
                    if (uiMode == Const.profileUI)
                      CustomToolbar(Intl.message("profile", name: "profile"),
                          onBackCallBack, Utils.notificationCount, false),
                    if (uiMode == Const.eBadgeDetailsUI)
                      CustomToolbar(
                          Intl.message("ebadge_details",
                              name: "ebadge_details"),
                          onBackCallBack,
                          Utils.notificationCount,
                          false),
                    if (uiMode == Const.contactDetailsUI)
                      CustomToolbar(
                          Intl.message("contact_details",
                              name: "contact_details"),
                          onBackCallBack,
                          Utils.notificationCount,
                          false),

                    // Middle Section
                    if (uiMode == Const.homeUI)
                      Expanded(
                        flex: 1,
                        child: Container(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                if (getEventsInit)
                                  Container(
                                    height: 216,
                                    child: CurrentEvents(responseEvents.data[0],
                                        0, handleEventDetailsCallback),
                                  ),
                                Container(
                                  padding: EdgeInsets.only(
                                      left: 20, right: 20, bottom: 20),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                      Intl.message("upcomingEvents",
                                          name: "upcomingEvents"),
                                      style: GoogleFonts.roboto(
                                          color: Color.fromRGBO(51, 51, 51, 1),
                                          fontStyle: FontStyle.normal,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700)),
                                ),
                                if (getEventsInit)
                                  Container(
                                    height: 100,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: responseEvents.data.length,
                                      itemBuilder: (context, index) {
                                        return UpcomingEvents(
                                            responseEvents.data[index],
                                            index,
                                            handleEventDetailsCallback);
                                      },
                                      // reverse: true,
                                      physics: BouncingScrollPhysics(),
                                    ),
                                  ),
                                Container(
                                  padding: EdgeInsets.only(
                                      left: 20, right: 20, top: 20),
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                      Intl.message("myEvents",
                                          name: "myEvents"),
                                      style: GoogleFonts.roboto(
                                          color: Color.fromRGBO(51, 51, 51, 1),
                                          fontStyle: FontStyle.normal,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700)),
                                ),
                                if (!isLoggedIn && isInit)
                                  Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          height: 30,
                                        ),
                                        Text(
                                            Intl.message("accessEventMessage",
                                                name: "accessEventMessage"),
                                            style: GoogleFonts.roboto(
                                                color: Color.fromRGBO(
                                                    51, 51, 51, 1),
                                                fontStyle: FontStyle.normal,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                                Intl.message(
                                                    "please",
                                                    name: "please"),
                                                style: GoogleFonts.roboto(
                                                    color: Color.fromRGBO(
                                                        51, 51, 51, 1),
                                                    fontStyle: FontStyle.normal,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            TextButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    PageRouteBuilder(
                                                      pageBuilder: (context,
                                                              animation,
                                                              secondaryAnimation) =>
                                                          SignUp(),
                                                      transitionsBuilder:
                                                          (context,
                                                              animation,
                                                              secondaryAnimation,
                                                              child) {
                                                        const begin = Offset(
                                                            1.0,
                                                            0.0); // Slide from right
                                                        const end = Offset.zero;
                                                        const curve =
                                                            Curves.easeInOut;
                                                        var tween = Tween(
                                                                begin: begin,
                                                                end: end)
                                                            .chain(CurveTween(
                                                                curve: curve));
                                                        var offsetAnimation =
                                                            animation
                                                                .drive(tween);
                                                        return SlideTransition(
                                                            position:
                                                                offsetAnimation,
                                                            child: child);
                                                      },
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                    Intl.message("signup",
                                                        name: "signup"),
                                                    style: GoogleFonts.roboto(
                                                        color: Color.fromRGBO(
                                                            69, 152, 209, 1),
                                                        fontStyle:
                                                            FontStyle.normal,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                            Text(Intl.message("or", name: "or"),
                                                style: GoogleFonts.roboto(
                                                    color: Color.fromRGBO(
                                                        51, 51, 51, 1),
                                                    fontStyle: FontStyle.normal,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.w600)),
                                            TextButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    PageRouteBuilder(
                                                      pageBuilder: (context,
                                                              animation,
                                                              secondaryAnimation) =>
                                                          SignIn(),
                                                      transitionsBuilder:
                                                          (context,
                                                              animation,
                                                              secondaryAnimation,
                                                              child) {
                                                        const begin = Offset(
                                                            1.0,
                                                            0.0); // Slide from right
                                                        const end = Offset.zero;
                                                        const curve =
                                                            Curves.easeInOut;
                                                        var tween = Tween(
                                                                begin: begin,
                                                                end: end)
                                                            .chain(CurveTween(
                                                                curve: curve));
                                                        var offsetAnimation =
                                                            animation
                                                                .drive(tween);
                                                        return SlideTransition(
                                                            position:
                                                                offsetAnimation,
                                                            child: child);
                                                      },
                                                    ),
                                                  );
                                                },
                                                child: Text(
                                                    Intl.message("login",
                                                        name: "login"),
                                                    style: GoogleFonts.roboto(
                                                        color: Color.fromRGBO(
                                                            69, 152, 209, 1),
                                                        fontStyle:
                                                            FontStyle.normal,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600))),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                if (isLoggedIn && userResponseEvents != null)
                                  if (userResponseEvents != null &&
                                      userResponseEvents!.data.isNotEmpty)
                                    Container(
                                      height: _calculateListViewHeight(
                                          userResponseEvents!.data.length),
                                      child: ListView.builder(
                                        padding: EdgeInsets.all(0),
                                        scrollDirection: Axis.vertical,
                                        itemCount:
                                            userResponseEvents!.data.length,
                                        itemBuilder: (context, index) {
                                          return MyEvents(
                                              userResponseEvents!.data[index],
                                              index,
                                              handleMyEventDetailsCallback);
                                        },
                                        // reverse: true,
                                        physics: BouncingScrollPhysics(),
                                      ),
                                    ),
                                if (isLoggedIn)
                                  SizedBox(
                                    height: 40,
                                  ),
                                if (userResponseEvents != null &&
                                    userResponseEvents!.data.isEmpty)
                                  SizedBox(
                                    height: 20,
                                  ),
                                if (userResponseEvents != null &&
                                    userResponseEvents!.data.isEmpty &&
                                    isLoggedIn)
                                  Text(
                                    Intl.message("msg_no_events",
                                        name: "msg_no_events"),
                                    style: GoogleFonts.roboto(
                                        color: Colors.black,
                                        fontStyle: FontStyle.normal,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (uiMode == Const.myContactsUI &&
                        responseContactList != null &&
                        responseContactList!.data!.length > 0)
                      Expanded(
                        flex: 1,
                        child: Container(
                          height: MediaQuery.of(context).size.height - 170,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            scrollDirection: Axis.vertical,
                            itemCount: contactItemList!.length,
                            itemBuilder: (context, index) {
                              return MyContact(index, contactItemList![index],
                                  handleMyContactDetails);
                            },
                            // reverse: true,
                            physics: BouncingScrollPhysics(),
                          ),
                        ),
                      ),
                    if (uiMode == Const.myContactsUI &&
                        responseContactList != null &&
                        responseContactList!.data!.length == 0)
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 40,
                            ),
                            Stack(alignment: Alignment.center, children: [
                              SvgPicture.asset('assets/ic_no_contact.svg'),
                              SvgPicture.asset(
                                'assets/ic_users.svg',
                                height: 100,
                                width: 100,
                              ),
                            ]),
                            SizedBox(
                              height: 40,
                            ),
                            Container(
                              height: 160,
                              width: double.infinity,
                              margin:
                                  new EdgeInsets.symmetric(horizontal: 20.0),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        Intl.message("add_new_contacts",
                                            name: "add_new_contacts"),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.roboto(
                                            fontSize: 20,
                                            decoration: TextDecoration.none,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black),
                                      ),
                                      SizedBox(
                                        height: 20,
                                      ),
                                      Text(
                                        Intl.message("header_scan",
                                            name: "header_scan"),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.roboto(
                                            fontSize: 15,
                                            height: 2,
                                            decoration: TextDecoration.none,
                                            fontWeight: FontWeight.w400,
                                            color: Colors.black),
                                      ),
                                    ]),
                              ),
                            ),
                            SizedBox(
                              height: 40,
                            ),
                            Center(
                                child: TextButton(
                              style: TextButton.styleFrom(
                                fixedSize: Size(230, 50),
                                backgroundColor:
                                    Color.fromRGBO(69, 152, 209, 1),
                                // Set the background color to black
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      25.0), // Set the border radius
                                ),
                              ),
                              onPressed: () async {
                                setState(() {
                                  uiMode = Const.scanUI;
                                });
                              },
                              child: SvgPicture.asset('assets/ic_camera.svg'),
                            ))
                          ],
                        ),
                      ),
                    if (uiMode == Const.myContactsUI &&
                        responseContactList == null)
                      Expanded(flex: 1, child: Container()),
                    if (uiMode == Const.scanUI)
                      Expanded(flex: 4, child: _scanner()),
                    if (uiMode == Const.eBadgesUI)
                      if (responseEbadges != null && uiMode == Const.eBadgesUI)
                        if (responseEbadges != null &&
                            responseEbadges!.data.isNotEmpty &&
                            uiMode == Const.eBadgesUI)
                          Expanded(
                            flex: 1,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              scrollDirection: Axis.vertical,
                              itemCount: responseEbadges!.data.length,
                              itemBuilder: (context, index) {
                                return Ebadge(
                                    index,
                                    responseEbadges!.data[index],
                                    handleEBadgeDetails);
                              },
                              // reverse: true,
                              physics: BouncingScrollPhysics(),
                            ),
                          ),
                    if (responseEbadges != null && uiMode == Const.eBadgesUI)
                      if (responseEbadges != null &&
                          responseEbadges!.data.isEmpty &&
                          uiMode == Const.eBadgesUI)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              SizedBox(
                                height:
                                    (MediaQuery.of(context).size.height / 2) -
                                        150,
                              ),
                              Text(
                                Intl.message("no_badges", name: "no_badges"),
                                style: GoogleFonts.roboto(
                                    color: Colors.black,
                                    fontStyle: FontStyle.normal,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w400),
                              ),
                            ],
                          ),
                        ),

                    if (uiMode == Const.eBadgesUI && responseEbadges == null)
                      Expanded(flex: 1, child: Container()),
                    if (uiMode == Const.profileUI && _responseUser != null)
                      Profile(
                          'try', "", handleProfileCallbacks, _responseUser!),
                    if (uiMode == Const.profileUI && _responseUser == null)
                      Expanded(flex: 1, child: Container()),
                    if (uiMode == Const.searchEventUI &&
                        getEventsInit &&
                        filteredEvents.isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: Container(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            scrollDirection: Axis.vertical,
                            itemCount: filteredEvents.length,
                            itemBuilder: (context, index) {
                              return CurrentEvents(filteredEvents[index], index,
                                  handleEventDetailsCallback);
                            },
                            // reverse: true,
                            physics: BouncingScrollPhysics(),
                          ),
                        ),
                      ),
                    if (uiMode == Const.searchEventUI &&
                        getEventsInit &&
                        filteredEvents.isEmpty &&
                        textController.text.toString().isNotEmpty)
                      Expanded(
                        flex: 1,
                        child: Container(
                          child: Padding(
                            padding: EdgeInsets.only(top: 30),
                            child: Text(
                              Intl.message("msg_no_events_search",
                                  name: "msg_no_events_search"),
                              style: GoogleFonts.roboto(
                                  color: Colors.black,
                                  fontStyle: FontStyle.normal,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400),
                            ),
                          ),
                        ),
                      ),
                    if (uiMode == Const.eBadgeDetailsUI)
                      EBadgeDetails(responseEbadges!.data[ebadgeItemPosition]),

                    // Bottom Section
                    CustomBottomBar(uiMode, handleCallback)
                  ],
                ),
                if (loader) Progressbar(loader),
              ],
            ),
          )),
    );
  }

  Future<void> playSound() async {
    try {
      await audioPlayer!.play();
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  Widget _scanner() {
    return Center(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Expanded(
              child: camState
                  ? Stack(
                      children: [
                        Center(
                          child: QrCamera(
                            onError: (context, error) => Text(
                              error.toString(),
                              style: TextStyle(color: Colors.red),
                            ),
                            cameraDirection: CameraDirection.BACK,
                            qrCodeCallback: (code) {
                              if (uiMode == Const.scanUI) {
                                setState(() {
                                  if (scanResult != code) {
                                    scanResult = code!;
                                    try {
                                      vibrateOnce();
                                      List<String> strResult =
                                          scanResult.split("-");
                                      if (strResult.length > 1) {
                                        addUserToContact(strResult);
                                      } else {
                                        Utils.showToast(Intl.message(
                                            "msg_scan_correct_ebadge",
                                            name: "msg_scan_correct_ebadge"));
                                      }
                                    } catch (e) {
                                      Utils.showToast(Intl.message(
                                          "msg_scan_correct_ebadge",
                                          name: "msg_scan_correct_ebadge"));
                                    }
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        Container(
                          decoration: ShapeDecoration(
                              shape: QrScannerOverlayShape(
                                  borderColor: Colors.green,
                                  borderRadius: 10,
                                  borderLength: 30,
                                  borderWidth: 10,
                                  cutOutSize: 300)),
                        ),
                      ],
                    )
                  : Center(child: Text("Camera inactive"))),
        ],
      ),
    );
  }
}
