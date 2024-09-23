import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class CircularImageView extends StatelessWidget {
  final String imageUrl;
  final double radius;
  bool isImageLoaded = false;

  CircularImageView({required this.imageUrl, this.radius = 25.0});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.white,
          child: Container(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SvgPicture.asset(
                    "assets/ic_user.svg",
                    width: (radius * 2),
                  ),
                  SvgPicture.asset(
                    "assets/ic_user_avatar.svg",
                  ),
                ],
              ),
            ),
          ),
        ),
        CircleAvatar(
          radius: radius,
          backgroundColor: Colors.transparent, // Placeholder background color
          backgroundImage: CachedNetworkImageProvider(
            imageUrl,
          ),
        ),
      ],
    );
  }
}
