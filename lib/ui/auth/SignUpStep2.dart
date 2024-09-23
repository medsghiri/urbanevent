import 'dart:io';
import 'dart:math';

import 'package:com.urbaevent/dialogs/Progressbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:com.urbaevent/model/ResponseAuthRole.dart';
import 'package:com.urbaevent/model/ResponseBusinessSector.dart';
import 'package:com.urbaevent/model/ResponseLogin.dart';
import 'package:com.urbaevent/model/common/ResponseError.dart';
import 'package:com.urbaevent/ui/auth/EmailVerification.dart';
import 'package:com.urbaevent/utils/Preference.dart';
import 'package:com.urbaevent/utils/ThemeColor.dart';
import 'package:com.urbaevent/utils/Urls.dart';
import 'package:com.urbaevent/utils/Utils.dart';
import 'package:com.urbaevent/widgets/CustomToolbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'SignIn.dart';
import 'dart:convert';

class SignUpStep2 extends StatefulWidget {
  final String name;
  final String phone;
  final String email;
  final String password;
  final String socialId;
  final String provider;
  final File? imageFile;

  SignUpStep2(this.name, this.phone, this.email, this.password, this.socialId,
      this.provider, this.imageFile);

  @override
  State<StatefulWidget> createState() => _SignUpStep2();
}

class _SignUpStep2 extends State<SignUpStep2> {
  bool loader = false;
  ImagePicker? picker;
  String imagePath = "";
  File? imageFile;
  int randomNumber = 1000;
  ResponseBusinessSector? responseBusinessSector;
  int businessSectorId = -1;

  TextEditingController _companyController = TextEditingController();
  TextEditingController _businessSectorController = TextEditingController();
  TextEditingController _functionController = TextEditingController();
  TextEditingController _countryController = TextEditingController();

  final FocusNode _companyFocus = FocusNode();
  final FocusNode _businessFocus = FocusNode();
  final FocusNode _functionFocus = FocusNode();
  final FocusNode _countryFocus = FocusNode();

  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool isExpanded = false;
  int _selectedIndex = -1;
  bool isChecked = false;

  void toggleCheckbox() {
    setState(() {
      isChecked = !isChecked;
    });
  }

  Future<void> redirectToTermsAndCondition() async {
    Preference preference = await Preference.getInstance();
    if (preference.getLanguage().toLowerCase() == "en") {
      await launchUrlString("https://urbaevent.ma/terms-and-conditions.html",
          mode: LaunchMode.externalApplication);
    } else {
      await launchUrlString("https://urbaevent.ma/terms-et-conditions.html",
          mode: LaunchMode.externalApplication);
    }
  }

  void _showAnchoredDialog(BuildContext context, Offset anchorOffset) {
    final OverlayState overlayState = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  isExpanded = false;
                });
                _overlayEntry?.remove();
              },
              child: Container(
                color: Colors.transparent, // Background dim effect
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
              ),
            ),
            Positioned(
              left: 38,
              right: 38,
              top: anchorOffset.dy + 30, // Adjust the offset as needed
              child: Card(
                  elevation: 2,
                  shadowColor:
                      Color.fromRGBO(158, 158, 158, 0.2549019607843137),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(10)),
                  ),
                  color: Color.fromRGBO(249, 249, 255, 1),
                  child: Container(
                      width: MediaQuery.of(context).size.width - 76,
                      height: 200,
                      child: ListView.builder(
                        padding: EdgeInsets.only(top: 10),
                        itemCount: responseBusinessSector!.data!.length,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                isExpanded = false;
                                businessSectorId =
                                    responseBusinessSector!.data![index].id!;
                                _selectedIndex = index;
                                _businessSectorController.text =
                                    responseBusinessSector!.data![index].name!;
                                _overlayEntry?.remove();
                              });
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(left: 10.0, right: 10),
                              child: Container(
                                height: 40.0,
                                color: _selectedIndex == index
                                    ? Color.fromRGBO(
                                        69, 152, 209, 0.15) // Highlighted color
                                    : Colors.transparent,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    responseBusinessSector!.data![index].name!,
                                    style: GoogleFonts.roboto(
                                        color: ThemeColor.textPrimary,
                                        fontStyle: FontStyle.normal,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w400),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ))),
            ),
          ],
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  Future<void> getAuthRole() async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();

    if (jwtToken.isNotEmpty) {
      final url = Uri.parse(Urls.baseURL + Urls.authRole);
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      final parsedJson = jsonDecode(response.body);

      if (response.statusCode == HttpStatus.ok) {
        print('Response Auth' + response.body);
        preference.saveAuthRole(ResponseAuthRole.fromJson(parsedJson));
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                EmailVerification(randomNumber.toString()),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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

  Future<void> getBusinessSector() async {
    final url = Uri.parse(Urls.baseURL + Urls.businessSector);

    final response = await http.get(url);
    final parsedJson = jsonDecode(response.body);
    if (response.statusCode == HttpStatus.ok) {
      print('Response' + response.body);
      responseBusinessSector = ResponseBusinessSector.fromJson(parsedJson);
    } else {
      print('Error' + response.body);
      final error = ResponseError.fromJson(parsedJson);
      Utils.showToast(error.error.message);
    }

    setState(() {
      loader = false;
    });
  }

  Future<void> _showImagePickerDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
            title: Text(
              Intl.message("select_image", name: "select_image"),
              style: GoogleFonts.roboto(
                  color: ThemeColor.textPrimary,
                  fontStyle: FontStyle.normal,
                  fontSize: 20,
                  fontWeight: FontWeight.w400),
            ),
            content: Container(
              height: 170,
              width: MediaQuery.of(context).size.width,
              alignment: Alignment.topLeft,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      funPickCameraImage();
                    },
                    child: Text(
                      Intl.message("camera", name: "camera"),
                      style: GoogleFonts.roboto(
                          color: Colors.black,
                          fontStyle: FontStyle.normal,
                          fontSize: 20,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      funPickGalleryImage();
                    },
                    child: Text(
                      Intl.message("gallery", name: "gallery"),
                      style: GoogleFonts.roboto(
                          color: Colors.black,
                          fontStyle: FontStyle.normal,
                          fontSize: 20,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      Intl.message("cancel", name: "cancel"),
                      style: GoogleFonts.roboto(
                          color: ThemeColor.textSecondary,
                          fontStyle: FontStyle.normal,
                          fontSize: 20,
                          fontWeight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ));
      },
    );
  }

  Future<void> _uploadImage() async {
    Preference preference = await Preference.getInstance();

    final jwtToken = preference.getToken();
    final url = Urls.baseURL + Urls.uploadPic;

    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
          url,
        ));

    request.headers['Authorization'] = 'Bearer $jwtToken';

    request.files.add(
      await http.MultipartFile.fromPath(
        'files',
        imageFile!.path,
      ),
    );

    // Add other form fields if needed
    request.fields['refId'] = preference.getLoginDetails()!.user.id.toString();

    request.fields['ref'] = 'plugin::users-permissions.user';

    request.fields['field'] = 'avatar';

    await request.send();

    getAuthRole();
  }

  Future<void> funPickCameraImage() async {
    picker = ImagePicker();
    final XFile? photo = await picker!.pickImage(source: ImageSource.camera);
    imagePath = photo!.path;
    setState(() {
      imageFile = File(imagePath);
    });
  }

  Future<void> funPickGalleryImage() async {
    picker = ImagePicker();
    final XFile? photo = await picker!.pickImage(source: ImageSource.gallery);
    imagePath = photo!.path;
    setState(() {
      imageFile = File(imagePath);
    });
  }

  void handleCallback() {
    Navigator.pop(context);
  }

  /*bool checkValidations() {
    if (_companyController.value.text.isEmpty) {
      Utils.showToast(
        Intl.message("msg_valid_company", name: "msg_valid_company"),
      );
      return false;
    } else if (_businessSectorController.value.text.isEmpty) {
      Utils.showToast(
        Intl.message("msg_valid_business_sector",
            name: "msg_valid_business_sector"),
      );
      return false;
    } else if (_functionController.value.text.isEmpty) {
      Utils.showToast(
        Intl.message("msg_valid_function", name: "msg_valid_function"),
      );
      return false;
    } else if (_countryController.value.text.isEmpty) {
      Utils.showToast(
          Intl.message("msg_valid_country", name: "msg_valid_country"));
      return false;
    }
    return true;
  }*/

  String generatePassword(int length) {
    const charset =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    final random = Random();
    String password = "";

    for (int i = 0; i < length; i++) {
      final randomIndex = random.nextInt(charset.length);
      password += charset[randomIndex];
    }

    return password;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color.fromRGBO(249, 249, 255, 1),
      // navigation bar color
      statusBarColor: Color.fromRGBO(249, 249, 255, 1), // status bar color
    ));
    return MaterialApp(
      home: _buildContent(),
    );
  }

  @override
  void initState() {
    super.initState();
    // getBusinessSector();
    if (widget.imageFile != null) {
      setState(() {
        imageFile = widget.imageFile;
      });
    }
  }

  Widget _buildContent() {
    Map<String, dynamic> removeEmptyKeys(Map<String, dynamic> json) {
      // Create a copy of the original JSON to avoid modifying it in place
      Map<String, dynamic> result = Map.from(json);

      // Create a list to store the keys to be removed
      List<String> keysToRemove = [];

      result.forEach((key, value) {
        if (value == null) {
          // Mark the key for removal if the value is null
          keysToRemove.add(key);
        }
        if (value == "") {
          // Mark the key for removal if the value is null
          keysToRemove.add(key);
        }
        if (value == -1) {
          // Mark the key for removal if the value is null
          keysToRemove.add(key);
        }
        if (value == '-1') {
          // Mark the key for removal if the value is null
          keysToRemove.add(key);
        }
      });

      // Remove the marked keys
      keysToRemove.forEach((key) {
        result.remove(key);
      });

      return result;
    }

    Future<void> register() async {
      setState(() {
        loader = true;
      });

      Random random = Random();
      randomNumber = 1000 + random.nextInt(9000);

      print('Email OTP $randomNumber');

      var url = Uri.parse(Urls.baseURL + Urls.register);
      var body;
      if (widget.socialId.isEmpty) {
        //Manual login
        url = Uri.parse(Urls.baseURL + Urls.register);

        body = {
          'name': widget.name,
          'email': widget.email,
          'username': widget.email,
          'phone': widget.phone,
          'provider': 'local',
          'password': widget.password,
          'businessSector': _businessSectorController.text.toString(),
          'company': _companyController.text.toString(),
          'jobPosition': _functionController.text.toString(),
          'country': _countryController.text.toString(),
          'confirmed': false.toString(),
          'emailOTP': randomNumber.toString(),
          'role': 1.toString()
        };
      } else {
        //Social Login
        body = {
          'name': widget.name,
          'email': widget.email,
          'username': widget.email,
          'phone': widget.phone,
          'socialId': widget.socialId,
          'provider': widget.provider,
          'password': generatePassword(8),
          'businessSector': businessSectorId.toString(),
          'company': _companyController.text.toString(),
          'jobPosition': _functionController.text.toString(),
          'country': _countryController.text.toString(),
          'confirmed': false.toString(),
          'emailOTP': randomNumber.toString(),
          'role': 1.toString()
        };
      }

      print(removeEmptyKeys(body));

      final response = await http.post(
        url,
        body: removeEmptyKeys(body),
      );

      final parsedJson = jsonDecode(response.body);

      if (response.statusCode == HttpStatus.ok) {
        final responseLogin = ResponseAuth.fromJson(parsedJson);

        Preference preference = await Preference.getInstance();
        preference.setUserId(responseLogin.user.id);
        preference.setToken(responseLogin.jwt);
        preference.saveLogin(responseLogin);
        if (imageFile == null) {
          getAuthRole();
        } else {
          _uploadImage();
        }
      } else {
        print((response.statusCode.toString() + 'Response: $response'));
        Utils.showToast(Intl.message("email_taken", name: "email_taken"));
        setState(() {
          loader = false;
        });
      }
    }

    final _customToolbar = CustomToolbar(
        Intl.message("sign_up", name: "sign_up"), handleCallback, -1, false);
    return WillPopScope(
      onWillPop: () async {
        if (_overlayEntry != null) _overlayEntry!.remove();
        return true;
      },
      child: Scaffold(
        appBar: null,
        body: Container(
          color: Color.fromRGBO(249, 249, 255, 1),
          child: Stack(children: [
            SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  SizedBox(height: 80.0),
                  Center(
                      child: Container(
                          margin: EdgeInsets.fromLTRB(20, 20, 20, 0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10.0),
                            color: Colors.white,
                          ),
                          child: Padding(
                              padding: EdgeInsets.fromLTRB(20.0, 20, 20, 0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(height: 16),
                                  Center(
                                    child: Stack(
                                      children: [
                                        if (imageFile == null)
                                          GestureDetector(
                                              onTap: () {
                                                _showImagePickerDialog();
                                              },
                                              child: ClipOval(
                                                child: SvgPicture.asset(
                                                    "assets/ic_user_camer.svg",
                                                    width: 80,
                                                    height: 80),
                                              )),
                                        if (imageFile != null)
                                          GestureDetector(
                                            onTap: () {
                                              _showImagePickerDialog();
                                            },
                                            child: ClipOval(
                                              child: Image.file(
                                                imageFile!,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: 32),
                                  SizedBox(
                                    height: 52,
                                    child: TextFormField(
                                      focusNode: _companyFocus,
                                      style: GoogleFonts.roboto(
                                          color: ThemeColor.textPrimary,
                                          fontStyle: FontStyle.normal,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400),
                                      controller: _companyController,
                                      decoration: InputDecoration(
                                        labelText: Intl.message("company",
                                            name: "company"),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                          borderRadius:
                                              BorderRadius.circular(25.0),
                                        ),
                                        fillColor:
                                            Color.fromRGBO(249, 249, 255, 1),
                                        filled: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.never,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () {
                                      /*final RenderBox renderBox = _anchorKey
                                          .currentContext!
                                          .findRenderObject() as RenderBox;
                                      final anchorPosition =
                                          renderBox.localToGlobal(Offset.zero);
                                      _showAnchoredDialog(
                                          context, anchorPosition);
                                      setState(() {
                                        isExpanded = true;
                                      });*/
                                    },
                                    child: SizedBox(
                                      height: 52,
                                      child: TextFormField(
                                        focusNode: _businessFocus,
                                        enabled: true,
                                        style: GoogleFonts.roboto(
                                            color: ThemeColor.textPrimary,
                                            fontStyle: FontStyle.normal,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w400),
                                        controller: _businessSectorController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        decoration: InputDecoration(
                                          labelStyle: TextStyle(
                                              color: Colors.black
                                                  .withOpacity(0.6)),
                                          labelText: Intl.message(
                                              "business_sector",
                                              name: "business_sector"),
                                          border: OutlineInputBorder(
                                            borderSide: BorderSide.none,
                                            borderRadius:
                                                BorderRadius.circular(25.0),
                                          ),
                                          fillColor:
                                              Color.fromRGBO(249, 249, 255, 1),
                                          filled: true,
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 20),
                                          floatingLabelBehavior:
                                              FloatingLabelBehavior.never,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  SizedBox(
                                    height: 52,
                                    child: TextFormField(
                                      focusNode: _functionFocus,
                                      style: GoogleFonts.roboto(
                                          color: ThemeColor.textPrimary,
                                          fontStyle: FontStyle.normal,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400),
                                      controller: _functionController,
                                      onEditingComplete: () {
                                        _countryFocus.requestFocus();
                                      },
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: Intl.message("function",
                                            name: "function"),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                          borderRadius:
                                              BorderRadius.circular(25.0),
                                        ),
                                        fillColor:
                                            Color.fromRGBO(249, 249, 255, 1),
                                        filled: true,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.never,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16.0),
                                  SizedBox(
                                    height: 52,
                                    child: TextFormField(
                                      focusNode: _countryFocus,
                                      style: GoogleFonts.roboto(
                                          color: ThemeColor.textPrimary,
                                          fontStyle: FontStyle.normal,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w400),
                                      controller: _countryController,
                                      onEditingComplete: () {
                                        if (isChecked) {
                                          register();
                                        }
                                        // if (checkValidations()) {
                                        //   register();
                                        // }
                                      },
                                      decoration: InputDecoration(
                                        labelText: Intl.message("country",
                                            name: "country"),
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                          borderRadius:
                                              BorderRadius.circular(25.0),
                                        ),
                                        filled: true,
                                        fillColor:
                                            Color.fromRGBO(249, 249, 255, 1),
                                        floatingLabelBehavior:
                                            FloatingLabelBehavior.never,
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 60.0),
                                  Row(
                                    children: [
                                      SizedBox(width: 10.0),
                                      InkWell(
                                        onTap: toggleCheckbox,
                                        child: Container(
                                          width: 16, // Adjust width as needed
                                          height: 16, // Adjust height as needed
                                          child: isChecked
                                              ? Image.asset(
                                                  'assets/checkbox.png',
                                                  width: 14,
                                                  // Adjust width as needed
                                                  height: 14,
                                                ) // Use your checked image
                                              : Image.asset(
                                                  'assets/square.png',
                                                  width: 14,
                                                  // Adjust width as needed
                                                  height: 14,
                                                  fit: BoxFit.contain,
                                                ), // Use your unchecked image
                                        ),
                                      ),
                                      SizedBox(width: 10.0),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: 10,
                                          ),
                                          Text(
                                              Intl.message("tc_label",
                                                  name: "tc_label"),
                                              style: GoogleFonts.roboto(
                                                  color: Colors.black,
                                                  fontStyle: FontStyle.normal,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400)),
                                          GestureDetector(
                                              onTap: () async {
                                                redirectToTermsAndCondition();
                                              },
                                              child: Container(
                                                width: 250,
                                                child: Text(
                                                    Intl.message("tc_text",
                                                        name: "tc_text"),
                                                    maxLines: 2,
                                                    style: GoogleFonts.roboto(
                                                        color: Color.fromRGBO(
                                                            235, 154, 68, 1),
                                                        fontStyle:
                                                            FontStyle.normal,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w400)),
                                              )),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 20.0),
                                  Center(
                                      child: TextButton(
                                          style: TextButton.styleFrom(
                                            fixedSize: Size(290, 50),
                                            backgroundColor:
                                                Color.fromRGBO(69, 152, 209, 1),
                                            // Set the background color to black
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                  25.0), // Set the border radius
                                            ),
                                          ),
                                          onPressed: () async {
                                            if (isChecked) {
                                              register();
                                            } else {
                                              Utils.showToast(Intl.message(
                                                  "msg_check_tc",
                                                  name: "msg_check_tc"));
                                            }
                                          },
                                          child: Text(
                                              Intl.message("next",
                                                  name: "next"),
                                              style: GoogleFonts.roboto(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight:
                                                      FontWeight.w500)))),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text(
                                          Intl.message("you_have_account",
                                              name: "you_have_account"),
                                          style: GoogleFonts.roboto(
                                              color: Colors.black,
                                              fontStyle: FontStyle.normal,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500)),
                                      TextButton(
                                          onPressed: () async {
                                            Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      SignIn()),
                                            );
                                          },
                                          child: Text(
                                              Intl.message("login_",
                                                  name: "login_"),
                                              style: GoogleFonts.roboto(
                                                  color: Color.fromRGBO(
                                                      235, 154, 68, 1),
                                                  fontStyle: FontStyle.normal,
                                                  fontSize: 16,

                                                  fontWeight:
                                                      FontWeight.w500))),
                                    ],
                                  ),
                                ],
                              )))),
                ],
              ),
            ),
            _customToolbar,
            if (loader) Progressbar(loader),
          ]),
        ),
      ),
    );
  }
}
