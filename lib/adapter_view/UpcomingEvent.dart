import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:com.urbaevent/model/events/ResponseEvents.dart';
import 'package:com.urbaevent/utils/Urls.dart';
import 'package:google_fonts/google_fonts.dart';

class UpcomingEvents extends StatefulWidget {
  final Function(int) callback;
  final position;
  final EventItem _datum;

  UpcomingEvents(this._datum, this.position, this.callback);

  @override
  State<UpcomingEvents> createState() => _UpcomingEvents();
}

class _UpcomingEvents extends State<UpcomingEvents> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.callback(widget.position);
      },
      child: Center(
          child: Container(
        height: 100,
        width: 141,
        margin: new EdgeInsets.only(left: 16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            // Set the border radius here
            child: CachedNetworkImage(
              fit: BoxFit.cover,
              height: 100,
              width: MediaQuery.of(context).size.width,
              imageUrl: Urls.imageURL + widget._datum.banner!.url,
              // Replace with your image URL
              placeholder: (context, url) => Container(
                  alignment: Alignment.center,
                  height: 50,
                  child: Center(
                      child: CircularProgressIndicator(
                    color: Colors.black.withOpacity(0.2),
                  ))),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12)),
                  // Set the border radius here
                  child: Image.asset(
                    'assets/bg_gradient.png',
                    height: 50,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )),
            ],
          ),
          Container(
            margin: EdgeInsets.all(10),
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget._datum.name,
                  style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w700),
                ),
                SizedBox(
                  height: 5,
                ),
                Text(
                  'By ${widget._datum.organizer}',
                  maxLines: 2,
                  style: GoogleFonts.roboto(
                      color: Colors.white,
                      fontStyle: FontStyle.normal,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w400),
                ),
              ],
            ),
          )
        ]),
      )),
    );
  }
}
