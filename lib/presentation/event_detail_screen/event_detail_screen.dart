import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../widgets/custom_image_view.dart';
import './bloc/event_detail_bloc.dart';
import './models/event_detail_model.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({Key? key}) : super(key: key);

  static Widget builder(BuildContext context) {
    return BlocProvider<EventDetailBloc>(
      create: (context) => EventDetailBloc(EventDetailState(
        eventDetailModel: EventDetailModel(),
      ))
        ..add(EventDetailInitialEvent()),
      child: const EventDetailScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF000000),
      appBar: _buildAppBar(context),
      body: BlocBuilder<EventDetailBloc, EventDetailState>(
        builder: (context, state) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMainEventSection(context),
                _buildUpcomingEventsSection(context),
                SizedBox(height: 16.h),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Color(0xFF000000),
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: 28.h, vertical: 18.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              children: [
                Container(
                  width: 26.h,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(2.h),
                  ),
                ),
                SizedBox(height: 2.h),
                Container(
                  width: 26.h,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(2.h),
                  ),
                ),
                SizedBox(height: 2.h),
                Container(
                  width: 26.h,
                  height: 5.h,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(2.h),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainEventSection(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 218.h),
          Padding(
            padding: EdgeInsets.only(left: 14.h),
            child: Text(
              'Sabato Sera ',
              style: TextStyleHelper.instance.display36RegularTiltWarp
                  .copyWith(height: 46 / 36),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 14.h),
            child: Text(
              'Disco Club',
              style: TextStyleHelper.instance.title16RegularTiltWarp
                  .copyWith(height: 21 / 16, color: Color(0x99FFFFFF)),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 14.h),
            child: Text(
              'Agosto 22 - 22:00 - 14:00 ',
              style: TextStyleHelper.instance.title16RegularTiltWarp
                  .copyWith(height: 21 / 16, color: Color(0x99FFFFFF)),
            ),
          ),
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(
              top: 14.h,
              left: 14.h,
              right: 16.h,
            ),
            child: ElevatedButton(
              onPressed: () {
                context
                    .read<EventDetailBloc>()
                    .add(ReserveButtonPressedEvent());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1D00FF),
                padding: EdgeInsets.symmetric(
                  horizontal: 30.h,
                  vertical: 10.h,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.h),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1D00FF),
                      Color(0xFF1900D8),
                      Color(0xFF110099),
                    ],
                    stops: [0.0, 0.5, 1.0],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18.h),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: 30.h,
                  vertical: 10.h,
                ),
                child: Text(
                  'RISERVA IL TUO POSTO ORA!',
                  style: TextStyleHelper.instance.title16RegularTiltWarp
                      .copyWith(height: 21 / 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(
            top: 10.h,
            left: 14.h,
          ),
          child: Text(
            'Prossimi eventi',
            style: TextStyleHelper.instance.headline32RegularTiltWarp
                .copyWith(height: 41 / 32),
          ),
        ),
        SizedBox(height: 4.h),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Padding(
              padding: EdgeInsets.only(right: 48.h),
              child: Text(
                'Sabato',
                style: TextStyleHelper.instance.display40RegularTiltWarp
                    .copyWith(height: 51 / 40),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 44.h),
              child: Text(
                'Agosto 23 - 23:00 - 33:00',
                style: TextStyleHelper.instance.label12RegularTiltWarp
                    .copyWith(height: 16 / 12, color: Color(0x7FFFFFFF)),
              ),
            ),
            SizedBox(height: 38.h),
            Padding(
              padding: EdgeInsets.only(right: 40.h),
              child: Text(
                'Venerdì',
                style: TextStyleHelper.instance.display40RegularTiltWarp
                    .copyWith(height: 51 / 40),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 44.h),
              child: Text(
                'Agosto 29 - 22:00 - 03:00',
                style: TextStyleHelper.instance.label12RegularTiltWarp
                    .copyWith(height: 16 / 12, color: Color(0x7FFFFFFF)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      height: 108.h,
      decoration: BoxDecoration(
        color: Color(0xFF000000),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF888888),
            blurRadius: 50.h,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 14.h,
        vertical: 28.h,
      ),
      child: BlocBuilder<EventDetailBloc, EventDetailState>(
        builder: (context, state) {
          return Container(
            height: 42.h,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () {
                            context.read<EventDetailBloc>().add(
                                  BottomNavItemSelectedEvent(0),
                                );
                          },
                          child: CustomImageView(
                            imagePath: ImageConstant.imgHome,
                            height: 34.h,
                            width: 34.h,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.read<EventDetailBloc>().add(
                                  BottomNavItemSelectedEvent(1),
                                );
                          },
                          child: CustomImageView(
                            imagePath: ImageConstant.imgShoppingCart,
                            height: 30.h,
                            width: 30.h,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.read<EventDetailBloc>().add(
                                  BottomNavItemSelectedEvent(2),
                                );
                          },
                          child: CustomImageView(
                            imagePath: ImageConstant.imgBell,
                            height: 34.h,
                            width: 34.h,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.read<EventDetailBloc>().add(
                                  BottomNavItemSelectedEvent(3),
                                );
                          },
                          child: CustomImageView(
                            imagePath: ImageConstant.imgUser,
                            height: 34.h,
                            width: 34.h,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(width: 158.h),
                      Text(
                        '1',
                        style: TextStyleHelper.instance.body14LightSFPro
                            .copyWith(height: 17 / 14),
                      ),
                      SizedBox(width: 101.h),
                      Text(
                        '1',
                        style: TextStyleHelper.instance.body14LightSFPro
                            .copyWith(height: 17 / 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
