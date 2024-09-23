import 'dart:convert';
import 'dart:io';

import 'package:com.urbaevent/adapter_view/MyScan.dart';
import 'package:com.urbaevent/model/agent/ResponseMyScans.dart';
import 'package:com.urbaevent/ui/content_ui/agent/AgentHomepage.dart';
import 'package:com.urbaevent/widgets/CustomBottomBarAgent.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:com.urbaevent/dialogs/Progressbar.dart';
import 'package:com.urbaevent/model/common/ResponseError.dart';
import 'package:com.urbaevent/ui/content_ui/home/HomePage.dart';
import 'package:com.urbaevent/utils/Preference.dart';
import 'package:com.urbaevent/utils/Urls.dart';
import 'package:com.urbaevent/utils/Utils.dart';
import 'package:com.urbaevent/widgets/CustomToolbar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class MyScans extends StatefulWidget {
  MyScans();

  @override
  State<StatefulWidget> createState() => _MyScans();
}

class _MyScans extends State<MyScans> {
  ResponseMyScans? responseMyScans;

  bool loader = false;
  bool isInit = false;



  Future<void> getMyScans() async {
    setState(() {
      loader = true;
    });

    Preference preference = await Preference.getInstance();

    final url = Uri.parse(Urls.baseURL +
        Urls.myScans +
        preference.getUserId().toString() +
        Urls.myScansFilter);
    final jwtToken = preference.getToken();
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $jwtToken'},
    );

    final parsedJson = jsonDecode(response.body);

    if (response.statusCode == HttpStatus.ok) {
      print('Response' + response.body);
      setState(() {
        isInit=true;
        responseMyScans = ResponseMyScans.fromJson(parsedJson);
      });
    } else {
      print('Response Error' + response.body);
      final error = ResponseError.fromJson(parsedJson);
      Utils.showToast(error.error.message);
    }
    setState(() {
      loader = false;
    });
  }

  void onCallBack() {
    setState(() {
      Navigator.pop(context);
    });
  }

  void handleCallback(int val) {
    setState(() {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => AgentHomePage(val)),
        (route) => false,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    // Set the initial status bar color to transparent
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
    ));

    getMyScans();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: Stack(
        children: [
          Container(color: Color.fromRGBO(249, 249, 255, 1)),
          Container(
            color: Color.fromRGBO(249, 249, 255, 1),
            width: double.infinity,
            height: double.infinity,
            child: Column(
              children: [
                CustomToolbar(Intl.message("my_scans", name: "my_scans"),
                    onCallBack, -1, false),
                if (responseMyScans != null &&
                    responseMyScans!.data!.length > 0 &&
                    isInit)
                  Expanded(
                    flex: 1,
                    child: Container(
                      child: ListView.builder(
                        padding: EdgeInsets.all(0),
                        scrollDirection: Axis.vertical,
                        itemCount: responseMyScans!.data!.length,
                        itemBuilder: (context, index) {
                          return MyScan(index, responseMyScans!.data![index]);
                        },
                        // reverse: true,
                        physics: BouncingScrollPhysics(),
                      ),
                    ),
                  ),
                if (responseMyScans != null &&
                    responseMyScans!.data!.length == 0 &&
                    isInit)
                  Expanded(
                    flex: 1,
                    child: Center(
                      child: Text(
                        Intl.message("no_scans", name: "no_scans"),
                        style: GoogleFonts.roboto(
                            color: Colors.black,
                            fontStyle: FontStyle.normal,
                            fontSize: 12,
                            fontWeight: FontWeight.w400),
                      ),
                    ),
                  ),
                if (responseMyScans == null || isInit == false)
                  Expanded(
                    flex: 1,
                    child: Container(),
                  ),
                CustomBottomBarAgent(-1, handleCallback)
              ],
            ),
          ),
          if (loader) Progressbar(loader)
        ],
      ),
    );
  }
}
