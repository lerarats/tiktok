import 'package:flutter/material.dart';


class TiktokNavItemWidget extends StatelessWidget {
  const TiktokNavItemWidget({
    super.key,
    this.icon,
    required this.label,
    this.imgPath,
    this.onTab,
    required this.isSelect,

  });

  final IconData? icon;
  final String label;
  final String? imgPath;
  final Function()? onTab;
  final bool isSelect;


  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTab,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon == null
              ? (imgPath != null
              ? Image.asset(
            imgPath!,
            width: 50.0,
            height: 50.0,
          )
              : SizedBox())
              : Icon(icon, color: isSelect ? Colors.red : Colors.white, size: 27.0),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}