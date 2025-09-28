
import 'package:booking_system_flutter/component/back_widget.dart';
import 'package:booking_system_flutter/component/loader_widget.dart';
import 'package:booking_system_flutter/main.dart';
import 'package:booking_system_flutter/model/category_model.dart';
import 'package:booking_system_flutter/network/rest_apis.dart';
import 'package:booking_system_flutter/screens/category/shimmer/category_shimmer.dart';
import 'package:booking_system_flutter/screens/dashboard/component/category_widget.dart';
import 'package:booking_system_flutter/utils/colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';

// NEW import for ads
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../component/empty_error_state_widget.dart';
import '../../utils/constant.dart';
import '../service/view_all_service_screen.dart';

class CategoryScreen extends StatefulWidget {
  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<List<CategoryData>> future;
  List<CategoryData> categoryList = [];

  int page = 1;
  bool isLastPage = false;
  bool isApiCalled = false;

  UniqueKey key = UniqueKey();

  // --- Banner Ad fields ---
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  // Use your real ad unit in production. While testing use the test id:
  // Test banner ad unit: ca-app-pub-3940256099942544/6300978111
  // Replace below with your production id when ready:
  final String _adUnitId = 'ca-app-pub-4177143032396996/4449706151';

  @override
  void initState() {
    super.initState();
    init();
    _initBannerAd(); // initialize and load banner
  }

  void init() async {
    future = getCategoryListWithPagination(page, categoryList: categoryList, lastPageCallBack: (val) {
      isLastPage = val;
    });
    if (page == 1) {
      key = UniqueKey();
    }
  }

  Future<void> _initBannerAd() async {
    // If you haven't initialized MobileAds elsewhere, it's safe to call here:
    // await MobileAds.instance.initialize();

    // Use test id while developing to avoid policy issues:
    const testAdUnitId = 'ca-app-pub-4177143032396996/4449706151';

    _bannerAd = BannerAd(
      // switch to _adUnitId for production. Use testAdUnitId while testing.
      adUnitId: testAdUnitId,
      size: AdSize.banner,
      request: AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          // Always dispose a failed ad.
          ad.dispose();
          debugPrint('❌ BannerAd failed to load: $error');
        },
        onAdOpened: (Ad ad) => debugPrint('📢 BannerAd opened.'),
        onAdClosed: (Ad ad) => debugPrint('🚪 BannerAd closed.'),
      ),
    );

    // load the ad
    await _bannerAd!.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    // compute banner size dims for the container
    final double bannerHeight = AdSize.banner.height.toDouble();
    final double bannerWidth = AdSize.banner.width.toDouble();

    return Scaffold(
      appBar: appBarWidget(
        language.category,
        textColor: Colors.white,
        textSize: APP_BAR_TEXT_SIZE,
        color: primaryColor,
        systemUiOverlayStyle: SystemUiOverlayStyle(statusBarIconBrightness: appStore.isDarkMode ? Brightness.light : Brightness.light, statusBarColor: context.primaryColor),
        showBack: Navigator.canPop(context),
        backWidget: BackWidget(),
      ),

      // Use Column so we can place content above and banner at bottom
      body: Column(
        children: [
          // Expanded: main content (keeps previous Stack structure)
          Expanded(
            child: Stack(
              children: [
                SnapHelperWidget<List<CategoryData>>(
                  initialData: cachedCategoryList,
                  future: future,
                  loadingWidget: CategoryShimmer(),
                  onSuccess: (snap) {
                    if (snap.isEmpty) {
                      return NoDataWidget(
                        title: language.noCategoryFound,
                        imageWidget: EmptyStateWidget(),
                      );
                    }

                    return AnimatedScrollView(
                      onSwipeRefresh: () async {
                        page = 1;

                        init();
                        setState(() {});

                        return await 2.seconds.delay;
                      },
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(16),
                      listAnimationType: ListAnimationType.FadeIn,
                      fadeInConfiguration: FadeInConfiguration(duration: 2.seconds),
                      onNextPage: () {
                        if (!isLastPage) {
                          page++;
                          appStore.setLoading(true);

                          init();
                          setState(() {});
                        }
                      },
                      children: [
                        AnimatedWrap(
                          key: key,
                          runSpacing: 16,
                          spacing: 16,
                          itemCount: snap.length,
                          listAnimationType: ListAnimationType.FadeIn,
                          fadeInConfiguration: FadeInConfiguration(duration: 2.seconds),
                          scaleConfiguration: ScaleConfiguration(duration: 300.milliseconds, delay: 50.milliseconds),
                          itemBuilder: (_, index) {
                            CategoryData data = snap[index];

                            return GestureDetector(
                              onTap: () {
                                ViewAllServiceScreen(categoryId: data.id.validate(), categoryName: data.name, isFromCategory: true).launch(context);
                              },
                              child: CategoryWidget(categoryData: data, width: context.width() / 4 - 24),
                            );
                          },
                        ).center(),
                      ],
                    );
                  },
                  errorBuilder: (error) {
                    return NoDataWidget(
                      title: error,
                      imageWidget: ErrorStateWidget(),
                      retryText: language.reload,
                      onRetry: () {
                        page = 1;
                        appStore.setLoading(true);

                        init();
                        setState(() {});
                      },
                    );
                  },
                ),
                Observer(builder: (BuildContext context) => LoaderWidget().visible(appStore.isLoading.validate())),
              ],
            ),
          ),

          // Banner Ad container (only shown when ad is loaded)
          if (_isAdLoaded && _bannerAd != null)
            Container(
              width: bannerWidth,
              height: bannerHeight,
              alignment: Alignment.center,
              color: Colors.transparent,
              child: AdWidget(ad: _bannerAd!),
            ),
          // Optional: reserve the same height even when ad isn't loaded to avoid layout jump:
          // else SizedBox(height: bannerHeight),
        ],
      ),
    );
  }
}
