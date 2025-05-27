import 'package:flutter/material.dart';
import 'package:kurshachtt/screen/home/tiktok_home_screen.dart';
import 'package:kurshachtt/provider/nav/nav_provider.dart';
import 'package:provider/provider.dart';

import 'nav_item_widget.dart';
class TiktokBottomNavigation extends StatelessWidget {
  const TiktokBottomNavigation({
    super.key,
    required this.selectIndex
  });
  final int selectIndex;


  @override
  Widget build(BuildContext context) {
    final navProvider= context.watch<NavProvider>();
    return Container(
      padding: const EdgeInsets.only(left: 10.0),
      color: Colors.black,
      width: double.infinity,
      height: 80.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          TiktokNavItemWidget(icon: Icons.home, label: "Home", isSelect: selectIndex==0,
            onTab:()=>navProvider.onChangePage(0),),
          SizedBox(width: 20.0),
          TiktokNavItemWidget(icon: Icons.search, label: "Search",isSelect: selectIndex==1,
            onTab:()=>navProvider.onChangePage(1),),
          SizedBox(width: 20.0),
          TiktokNavItemWidget(imgPath: "assets/tiktok/add.png", label: "",isSelect: selectIndex==2,
            onTab:()=>navProvider.onChangePage(2),),
          SizedBox(width: 20.0),
          TiktokNavItemWidget(icon: Icons.bar_chart, label: "Statistic",isSelect: selectIndex==3,
            onTab:()=>navProvider.onChangePage(3),),
          SizedBox(width: 20.0),
          TiktokNavItemWidget(icon: Icons.person, label: "Person",isSelect: selectIndex==4,
            onTab:()=>navProvider.onChangePage(4),),
        ],
      ),
    );
  }
}