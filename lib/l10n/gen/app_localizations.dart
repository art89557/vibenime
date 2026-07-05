import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'VibeNime'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your vibe, your anime.'**
  String get appTagline;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navSchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get navSchedule;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfile;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get settingsFriends;

  /// No description provided for @settingsMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get settingsMessages;

  /// No description provided for @settingsActivityFeed.
  ///
  /// In en, this message translates to:
  /// **'Activity Feed'**
  String get settingsActivityFeed;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsPlayer.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get settingsPlayer;

  /// No description provided for @settingsSocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get settingsSocial;

  /// No description provided for @settingsDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get settingsDownloads;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacy;

  /// No description provided for @settingsTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get settingsTerms;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get settingsLogout;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeSystem;

  /// No description provided for @languageIndonesian.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesian;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Library'**
  String get libraryTitle;

  /// No description provided for @libraryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryAll;

  /// No description provided for @libraryWatching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get libraryWatching;

  /// No description provided for @libraryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get libraryCompleted;

  /// No description provided for @libraryPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get libraryPlanning;

  /// No description provided for @libraryEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmptyAll;

  /// No description provided for @libraryEmptyWatching.
  ///
  /// In en, this message translates to:
  /// **'No anime currently watching'**
  String get libraryEmptyWatching;

  /// No description provided for @libraryEmptyCompleted.
  ///
  /// In en, this message translates to:
  /// **'No anime completed yet'**
  String get libraryEmptyCompleted;

  /// No description provided for @libraryEmptyPlanning.
  ///
  /// In en, this message translates to:
  /// **'Watch list is empty'**
  String get libraryEmptyPlanning;

  /// No description provided for @addToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get addToList;

  /// No description provided for @removeFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from List'**
  String get removeFromList;

  /// No description provided for @alreadyInList.
  ///
  /// In en, this message translates to:
  /// **'Already in list'**
  String get alreadyInList;

  /// No description provided for @actionWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get actionWatch;

  /// No description provided for @actionPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get actionPlay;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get actionLoading;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get actionLogin;

  /// No description provided for @actionRegister.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get actionRegister;

  /// No description provided for @actionSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionSubmit;

  /// No description provided for @profileEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileEdit;

  /// No description provided for @profileUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get profileUsername;

  /// No description provided for @profileBio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get profileBio;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profileBanner.
  ///
  /// In en, this message translates to:
  /// **'Banner'**
  String get profileBanner;

  /// No description provided for @profileAvatar.
  ///
  /// In en, this message translates to:
  /// **'Avatar'**
  String get profileAvatar;

  /// No description provided for @profileAvatarBorder.
  ///
  /// In en, this message translates to:
  /// **'Avatar Border'**
  String get profileAvatarBorder;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profileChangePassword;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get profilePrivacy;

  /// No description provided for @friendsTitle.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsTitle;

  /// No description provided for @friendsSearch.
  ///
  /// In en, this message translates to:
  /// **'Find Friends'**
  String get friendsSearch;

  /// No description provided for @friendsList.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friendsList;

  /// No description provided for @friendsIncoming.
  ///
  /// In en, this message translates to:
  /// **'Incoming'**
  String get friendsIncoming;

  /// No description provided for @friendsOutgoing.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get friendsOutgoing;

  /// No description provided for @friendsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Friend'**
  String get friendsAdd;

  /// No description provided for @friendsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get friendsAccept;

  /// No description provided for @friendsReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get friendsReject;

  /// No description provided for @friendsBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get friendsBlock;

  /// No description provided for @friendsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get friendsRemove;

  /// No description provided for @messagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messagesTitle;

  /// No description provided for @messagesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get messagesEmpty;

  /// No description provided for @messagesType.
  ///
  /// In en, this message translates to:
  /// **'Type a message...'**
  String get messagesType;

  /// No description provided for @messagesSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get messagesSend;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get errorNetwork;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFound;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get loginNoAccount;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// No description provided for @registerConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get registerConfirmPassword;

  /// No description provided for @registerHasAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get registerHasAccount;

  /// No description provided for @homeTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get homeTrending;

  /// No description provided for @homeTrendingSub.
  ///
  /// In en, this message translates to:
  /// **'most watched right now'**
  String get homeTrendingSub;

  /// No description provided for @homeForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get homeForYou;

  /// No description provided for @homeForYouSub.
  ///
  /// In en, this message translates to:
  /// **'this season\'s picks'**
  String get homeForYouSub;

  /// No description provided for @homeForYouBasedOn.
  ///
  /// In en, this message translates to:
  /// **'based on {genres}'**
  String homeForYouBasedOn(String genres);

  /// No description provided for @homeTopAllTime.
  ///
  /// In en, this message translates to:
  /// **'Top of all time'**
  String get homeTopAllTime;

  /// No description provided for @homeTopAllTimeSub.
  ///
  /// In en, this message translates to:
  /// **'highest rated'**
  String get homeTopAllTimeSub;

  /// No description provided for @homeUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get homeUpcoming;

  /// No description provided for @homeUpcomingSub.
  ///
  /// In en, this message translates to:
  /// **'coming soon'**
  String get homeUpcomingSub;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search anime...'**
  String get searchHint;

  /// No description provided for @searchEmptyState.
  ///
  /// In en, this message translates to:
  /// **'Start typing to search anime'**
  String get searchEmptyState;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results.'**
  String get searchNoResults;

  /// No description provided for @settingsReduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce animations'**
  String get settingsReduceMotion;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Release Schedule'**
  String get scheduleTitle;

  /// No description provided for @scheduleEmptyToday.
  ///
  /// In en, this message translates to:
  /// **'No anime airing today.'**
  String get scheduleEmptyToday;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutConfirmTitle;

  /// No description provided for @logoutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out. Local data (history, favorites) stays safe.'**
  String get logoutConfirmBody;

  /// No description provided for @profileCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create New Account'**
  String get profileCreateAccount;

  /// No description provided for @detailTabEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get detailTabEpisodes;

  /// No description provided for @detailTabSynopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis'**
  String get detailTabSynopsis;

  /// No description provided for @detailTabCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get detailTabCharacters;

  /// No description provided for @detailTabDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Discussion'**
  String get detailTabDiscussion;

  /// No description provided for @detailNoSynopsis.
  ///
  /// In en, this message translates to:
  /// **'Synopsis not available yet.'**
  String get detailNoSynopsis;

  /// No description provided for @activityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No friend activity yet'**
  String get activityEmpty;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingStart;

  /// No description provided for @onboardingTitle1.
  ///
  /// In en, this message translates to:
  /// **'Welcome to VibeNime'**
  String get onboardingTitle1;

  /// No description provided for @onboardingDesc1.
  ///
  /// In en, this message translates to:
  /// **'Stream your favorite anime in the best quality. Your vibe, your anime.'**
  String get onboardingDesc1;

  /// No description provided for @onboardingTitle2.
  ///
  /// In en, this message translates to:
  /// **'Full-Featured'**
  String get onboardingTitle2;

  /// No description provided for @onboardingDesc2.
  ///
  /// In en, this message translates to:
  /// **'Download episodes for offline, watch party with friends, and real-time chat.'**
  String get onboardingDesc2;

  /// No description provided for @onboardingTitle3.
  ///
  /// In en, this message translates to:
  /// **'Start Now'**
  String get onboardingTitle3;

  /// No description provided for @onboardingDesc3.
  ///
  /// In en, this message translates to:
  /// **'Create a free account and explore thousands of anime.'**
  String get onboardingDesc3;

  /// No description provided for @genrePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Mood / Genre'**
  String get genrePickerTitle;

  /// No description provided for @genrePickerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'pick a few to filter your search'**
  String get genrePickerSubtitle;

  /// No description provided for @genrePickerClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get genrePickerClear;

  /// No description provided for @genrePickerShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get genrePickerShowAll;

  /// No description provided for @genrePickerApply.
  ///
  /// In en, this message translates to:
  /// **'Apply · {count} selected'**
  String genrePickerApply(int count);

  /// No description provided for @discoverTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get discoverTrending;

  /// No description provided for @discoverPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get discoverPopular;

  /// No description provided for @discoverTopRated.
  ///
  /// In en, this message translates to:
  /// **'Top Rated'**
  String get discoverTopRated;

  /// No description provided for @discoverUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get discoverUpcoming;

  /// No description provided for @discoverEmpty.
  ///
  /// In en, this message translates to:
  /// **'No anime in this section yet.'**
  String get discoverEmpty;

  /// No description provided for @friendSendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get friendSendMessage;

  /// No description provided for @friendPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get friendPending;

  /// No description provided for @friendUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get friendUnblock;

  /// No description provided for @friendRemoveConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove friendship?'**
  String get friendRemoveConfirm;

  /// No description provided for @friendBlockConfirm.
  ///
  /// In en, this message translates to:
  /// **'Block user?'**
  String get friendBlockConfirm;

  /// No description provided for @friendBlockConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This user won\'t be able to chat with you or see your activity.'**
  String get friendBlockConfirmBody;

  /// No description provided for @wpPartyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Party unavailable'**
  String get wpPartyUnavailable;

  /// No description provided for @wpEndConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End party?'**
  String get wpEndConfirmTitle;

  /// No description provided for @wpEndConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All viewers will be disconnected. Are you sure?'**
  String get wpEndConfirmBody;

  /// No description provided for @wpEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get wpEnd;

  /// No description provided for @wpEnded.
  ///
  /// In en, this message translates to:
  /// **'Party ended'**
  String get wpEnded;

  /// No description provided for @wpEndFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to end'**
  String get wpEndFailed;

  /// No description provided for @wpEndTooltip.
  ///
  /// In en, this message translates to:
  /// **'End party'**
  String get wpEndTooltip;

  /// No description provided for @wpLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get wpLeave;

  /// No description provided for @wpYouAreHost.
  ///
  /// In en, this message translates to:
  /// **'You\'re the host'**
  String get wpYouAreHost;

  /// No description provided for @wpHostedBy.
  ///
  /// In en, this message translates to:
  /// **'Party @{username}'**
  String wpHostedBy(String username);

  /// No description provided for @wpEpViewers.
  ///
  /// In en, this message translates to:
  /// **'EP {ep} · {count} watching'**
  String wpEpViewers(int ep, int count);

  /// No description provided for @wpEpisodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'Episode not found'**
  String get wpEpisodeNotFound;

  /// No description provided for @wpNoSource.
  ///
  /// In en, this message translates to:
  /// **'No source available'**
  String get wpNoSource;

  /// No description provided for @wpSyncToHost.
  ///
  /// In en, this message translates to:
  /// **'Synced to host'**
  String get wpSyncToHost;

  /// No description provided for @wpYoutubeOnly.
  ///
  /// In en, this message translates to:
  /// **'Watch Party only supports YouTube sources in this version.'**
  String get wpYoutubeOnly;

  /// No description provided for @wpEndedTitle.
  ///
  /// In en, this message translates to:
  /// **'The party has ended'**
  String get wpEndedTitle;

  /// No description provided for @wpEndedBody.
  ///
  /// In en, this message translates to:
  /// **'The host ended the watch session.'**
  String get wpEndedBody;

  /// No description provided for @wpChatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send'**
  String get wpChatSendFailed;

  /// No description provided for @wpChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No chat yet — say hi!'**
  String get wpChatEmpty;

  /// No description provided for @wpChatLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Log in to chat'**
  String get wpChatLoginRequired;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch History'**
  String get historyTitle;

  /// No description provided for @historyViewCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact view'**
  String get historyViewCompact;

  /// No description provided for @historyViewDetailed.
  ///
  /// In en, this message translates to:
  /// **'Detailed view'**
  String get historyViewDetailed;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No watch history yet'**
  String get historyEmpty;

  /// No description provided for @rankingTitle.
  ///
  /// In en, this message translates to:
  /// **'Anime Rankings'**
  String get rankingTitle;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'hi, {name} —'**
  String homeGreeting(String name);

  /// No description provided for @homeVibe.
  ///
  /// In en, this message translates to:
  /// **'what\'s your vibe today?'**
  String get homeVibe;

  /// No description provided for @homeRecentlyWatched.
  ///
  /// In en, this message translates to:
  /// **'Recently Watched'**
  String get homeRecentlyWatched;

  /// No description provided for @homeResumeEp.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE · EP {ep}'**
  String homeResumeEp(String ep);

  /// No description provided for @homeResumeNextEp.
  ///
  /// In en, this message translates to:
  /// **'UP NEXT · EP {ep}'**
  String homeResumeNextEp(String ep);

  /// No description provided for @homeResumeNextLabel.
  ///
  /// In en, this message translates to:
  /// **'New episode'**
  String get homeResumeNextLabel;

  /// No description provided for @homeSyncedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Synced across devices'**
  String get homeSyncedTooltip;

  /// No description provided for @settingsFollowSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsFollowSystem;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'VibeNime\'s signature theme — recommended'**
  String get settingsThemeDarkDesc;

  /// No description provided for @settingsThemeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Great for daytime'**
  String get settingsThemeLightDesc;

  /// No description provided for @settingsThemeSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Match your phone setting'**
  String get settingsThemeSystemDesc;

  /// No description provided for @settingsThemePick.
  ///
  /// In en, this message translates to:
  /// **'Choose Theme'**
  String get settingsThemePick;

  /// No description provided for @settingsTitleLanguage.
  ///
  /// In en, this message translates to:
  /// **'Title Language'**
  String get settingsTitleLanguage;

  /// No description provided for @settingsSubtitleLanguage.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Language'**
  String get settingsSubtitleLanguage;

  /// No description provided for @settingsSubtitleSize.
  ///
  /// In en, this message translates to:
  /// **'Subtitle Size'**
  String get settingsSubtitleSize;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout?'**
  String get logoutTitle;

  /// No description provided for @logoutBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out. Local data (history, favorites) stays safe.'**
  String get logoutBody;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonLogout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get commonLogout;

  /// No description provided for @commonEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get commonEmpty;

  /// No description provided for @settingsLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'logged in'**
  String get settingsLoggedIn;

  /// No description provided for @settingsNotLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'not logged in'**
  String get settingsNotLoggedIn;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'DISPLAY'**
  String get settingsDisplay;

  /// No description provided for @settingsQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get settingsQuality;

  /// No description provided for @settingsAutoNext.
  ///
  /// In en, this message translates to:
  /// **'Auto-next episode'**
  String get settingsAutoNext;

  /// No description provided for @settingsAutoSkip.
  ///
  /// In en, this message translates to:
  /// **'Auto-skip intro/outro'**
  String get settingsAutoSkip;

  /// No description provided for @settingsWatchParty.
  ///
  /// In en, this message translates to:
  /// **'Watch party'**
  String get settingsWatchParty;

  /// No description provided for @settingsMyActivity.
  ///
  /// In en, this message translates to:
  /// **'My activity'**
  String get settingsMyActivity;

  /// No description provided for @settingsLiveReactions.
  ///
  /// In en, this message translates to:
  /// **'Live reactions'**
  String get settingsLiveReactions;

  /// No description provided for @settingsDefaultQuality.
  ///
  /// In en, this message translates to:
  /// **'Default quality'**
  String get settingsDefaultQuality;

  /// No description provided for @settingsSavedEpisodes.
  ///
  /// In en, this message translates to:
  /// **'Saved episodes'**
  String get settingsSavedEpisodes;

  /// No description provided for @downloadChooseQuality.
  ///
  /// In en, this message translates to:
  /// **'Choose download quality'**
  String get downloadChooseQuality;

  /// No description provided for @downloadViaBrowser.
  ///
  /// In en, this message translates to:
  /// **'via browser'**
  String get downloadViaBrowser;

  /// No description provided for @downloadOpenedInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Opened in browser to download'**
  String get downloadOpenedInBrowser;

  /// No description provided for @settingsManageSub.
  ///
  /// In en, this message translates to:
  /// **'Search & manage'**
  String get settingsManageSub;

  /// No description provided for @privacyFriends.
  ///
  /// In en, this message translates to:
  /// **'friends'**
  String get privacyFriends;

  /// No description provided for @privacyPublic.
  ///
  /// In en, this message translates to:
  /// **'public'**
  String get privacyPublic;

  /// No description provided for @adminStatsGlobal.
  ///
  /// In en, this message translates to:
  /// **'global stats'**
  String get adminStatsGlobal;

  /// No description provided for @adminMessageModeration.
  ///
  /// In en, this message translates to:
  /// **'Message Moderation'**
  String get adminMessageModeration;

  /// No description provided for @adminDeleteMessages.
  ///
  /// In en, this message translates to:
  /// **'delete messages'**
  String get adminDeleteMessages;

  /// No description provided for @adminManageAnime.
  ///
  /// In en, this message translates to:
  /// **'manage anime'**
  String get adminManageAnime;

  /// No description provided for @adminError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String adminError(String error);

  /// No description provided for @adminFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String adminFailed(String error);

  /// No description provided for @adminNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get adminNoMessages;

  /// No description provided for @adminDeleteMessageQ.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get adminDeleteMessageQ;

  /// No description provided for @adminDeleteMessageBody.
  ///
  /// In en, this message translates to:
  /// **'This message will be permanently deleted.'**
  String get adminDeleteMessageBody;

  /// No description provided for @adminMessageDeleted.
  ///
  /// In en, this message translates to:
  /// **'Message deleted'**
  String get adminMessageDeleted;

  /// No description provided for @adminStatsError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}\n\nMake sure admin_roles.sql has been run and your account is super_admin.'**
  String adminStatsError(String error);

  /// No description provided for @adminStatsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Stats unavailable'**
  String get adminStatsUnavailable;

  /// No description provided for @adminTotalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total Users'**
  String get adminTotalUsers;

  /// No description provided for @adminSignupsToday.
  ///
  /// In en, this message translates to:
  /// **'Signups Today'**
  String get adminSignupsToday;

  /// No description provided for @adminActive7d.
  ///
  /// In en, this message translates to:
  /// **'Active 7 Days'**
  String get adminActive7d;

  /// No description provided for @adminMessagesLabel.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get adminMessagesLabel;

  /// No description provided for @adminFriendships.
  ///
  /// In en, this message translates to:
  /// **'Friendships'**
  String get adminFriendships;

  /// No description provided for @adminActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'ADMIN ACTIONS'**
  String get adminActionsLabel;

  /// No description provided for @adminUsersSub.
  ///
  /// In en, this message translates to:
  /// **'{users} users · {admins} admin'**
  String adminUsersSub(int users, int admins);

  /// No description provided for @adminModerateSub.
  ///
  /// In en, this message translates to:
  /// **'Review & delete messages'**
  String get adminModerateSub;

  /// No description provided for @adminCatalogSub.
  ///
  /// In en, this message translates to:
  /// **'Manage anime + sources'**
  String get adminCatalogSub;

  /// No description provided for @adminSignupsWeek.
  ///
  /// In en, this message translates to:
  /// **'This week: {count} signups'**
  String adminSignupsWeek(int count);

  /// No description provided for @adminSignupsTodayPct.
  ///
  /// In en, this message translates to:
  /// **'Today: {today} ({pct}% of week)'**
  String adminSignupsTodayPct(int today, String pct);

  /// No description provided for @adminSearchUserHint.
  ///
  /// In en, this message translates to:
  /// **'Search username or email...'**
  String get adminSearchUserHint;

  /// No description provided for @adminNoUsers.
  ///
  /// In en, this message translates to:
  /// **'No users'**
  String get adminNoUsers;

  /// No description provided for @adminRoleUpdated.
  ///
  /// In en, this message translates to:
  /// **'Role updated → {role}'**
  String adminRoleUpdated(String role);

  /// No description provided for @adminBanQ.
  ///
  /// In en, this message translates to:
  /// **'Ban @{username}?'**
  String adminBanQ(String username);

  /// No description provided for @adminReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get adminReason;

  /// No description provided for @adminUserBanned.
  ///
  /// In en, this message translates to:
  /// **'User banned'**
  String get adminUserBanned;

  /// No description provided for @adminUserUnbanned.
  ///
  /// In en, this message translates to:
  /// **'Unbanned'**
  String get adminUserUnbanned;

  /// No description provided for @adminPromote.
  ///
  /// In en, this message translates to:
  /// **'Promote to Admin'**
  String get adminPromote;

  /// No description provided for @adminDemote.
  ///
  /// In en, this message translates to:
  /// **'Demote to User'**
  String get adminDemote;

  /// No description provided for @adminBanUser.
  ///
  /// In en, this message translates to:
  /// **'Ban User'**
  String get adminBanUser;

  /// No description provided for @adminUnbanUser.
  ///
  /// In en, this message translates to:
  /// **'Unban User'**
  String get adminUnbanUser;

  /// No description provided for @adminAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get adminAdd;

  /// No description provided for @adminLogoutBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out and returned to the login screen.'**
  String get adminLogoutBody;

  /// No description provided for @adminAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied'**
  String get adminAccessDenied;

  /// No description provided for @adminNotAdminBody.
  ///
  /// In en, this message translates to:
  /// **'Account {email} is not an admin.\n\nThe Admin Panel is for catalog managers.\nContact an admin for access, or use an admin account.'**
  String adminNotAdminBody(String email);

  /// No description provided for @adminBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get adminBackHome;

  /// No description provided for @adminLoggedInAs.
  ///
  /// In en, this message translates to:
  /// **'Logged in as'**
  String get adminLoggedInAs;

  /// No description provided for @adminSearchCatalogHint.
  ///
  /// In en, this message translates to:
  /// **'Search anime ID or notes...'**
  String get adminSearchCatalogHint;

  /// No description provided for @adminFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get adminFilterAll;

  /// No description provided for @adminNoFilterResults.
  ///
  /// In en, this message translates to:
  /// **'No filter results'**
  String get adminNoFilterResults;

  /// No description provided for @adminCatalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No videos in catalog yet'**
  String get adminCatalogEmpty;

  /// No description provided for @adminCatalogEmptyFilterSub.
  ///
  /// In en, this message translates to:
  /// **'Try clearing the filter or keyword.'**
  String get adminCatalogEmptyFilterSub;

  /// No description provided for @adminCatalogEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Tap Add to insert the first video,\nor Bulk Insert (📋 above) for a batch.'**
  String get adminCatalogEmptySub;

  /// No description provided for @adminAddVideo.
  ///
  /// In en, this message translates to:
  /// **'Add Video'**
  String get adminAddVideo;

  /// No description provided for @adminValIdPositive.
  ///
  /// In en, this message translates to:
  /// **'AniList ID must be a positive number'**
  String get adminValIdPositive;

  /// No description provided for @adminValEpPositive.
  ///
  /// In en, this message translates to:
  /// **'Episode number must be a positive number'**
  String get adminValEpPositive;

  /// No description provided for @adminValUrl.
  ///
  /// In en, this message translates to:
  /// **'Video URL must be a valid URL (https://...)'**
  String get adminValUrl;

  /// No description provided for @adminSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get adminSaved;

  /// No description provided for @adminAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get adminAdded;

  /// No description provided for @adminDeleteVideoQ.
  ///
  /// In en, this message translates to:
  /// **'Delete video?'**
  String get adminDeleteVideoQ;

  /// No description provided for @adminDeleteVideoBody.
  ///
  /// In en, this message translates to:
  /// **'This source will be removed from the catalog. Can be undone within 5 seconds.'**
  String get adminDeleteVideoBody;

  /// No description provided for @adminVideoDeleted.
  ///
  /// In en, this message translates to:
  /// **'Video deleted'**
  String get adminVideoDeleted;

  /// No description provided for @adminEnterIdFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter an AniList ID first'**
  String get adminEnterIdFirst;

  /// No description provided for @adminOpenLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open link'**
  String get adminOpenLinkFailed;

  /// No description provided for @adminDeleteThisVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete This Video'**
  String get adminDeleteThisVideo;

  /// No description provided for @adminSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get adminSaveChanges;

  /// No description provided for @adminAddToCatalog.
  ///
  /// In en, this message translates to:
  /// **'Add to Catalog'**
  String get adminAddToCatalog;

  /// No description provided for @adminCheck.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get adminCheck;

  /// No description provided for @adminSubtitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Subtitle URL (optional)'**
  String get adminSubtitleOptional;

  /// No description provided for @adminSearchingAniList.
  ///
  /// In en, this message translates to:
  /// **'Searching AniList...'**
  String get adminSearchingAniList;

  /// No description provided for @adminIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4082'**
  String get adminIdHint;

  /// No description provided for @adminPriorityPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary — used first by the player'**
  String get adminPriorityPrimary;

  /// No description provided for @adminPriorityDefault.
  ///
  /// In en, this message translates to:
  /// **'Default — normal fallback'**
  String get adminPriorityDefault;

  /// No description provided for @adminPriorityBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup — second fallback'**
  String get adminPriorityBackup;

  /// No description provided for @adminPriorityLast.
  ///
  /// In en, this message translates to:
  /// **'Last resort'**
  String get adminPriorityLast;

  /// No description provided for @adminPrioritySmaller.
  ///
  /// In en, this message translates to:
  /// **'smaller = chosen first'**
  String get adminPrioritySmaller;

  /// No description provided for @adminEmptyUrlList.
  ///
  /// In en, this message translates to:
  /// **'URL list is empty'**
  String get adminEmptyUrlList;

  /// No description provided for @adminVideosSaved.
  ///
  /// In en, this message translates to:
  /// **'{count} videos saved'**
  String adminVideosSaved(int count);

  /// No description provided for @adminSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get adminSaving;

  /// No description provided for @adminInsertN.
  ///
  /// In en, this message translates to:
  /// **'Insert {count}'**
  String adminInsertN(int count);

  /// No description provided for @adminEpisodeFrom.
  ///
  /// In en, this message translates to:
  /// **'Episode From'**
  String get adminEpisodeFrom;

  /// No description provided for @adminEpisodeTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get adminEpisodeTo;

  /// No description provided for @adminStartFromEpisode.
  ///
  /// In en, this message translates to:
  /// **'Start from Episode'**
  String get adminStartFromEpisode;

  /// No description provided for @adminUrlListLabel.
  ///
  /// In en, this message translates to:
  /// **'URL List (1 per line)'**
  String get adminUrlListLabel;

  /// No description provided for @adminNotesPrefixHint.
  ///
  /// In en, this message translates to:
  /// **'Notes per row → \"<prefix> <episode>\". e.g. \"Astro Boy 1963 — EP 1\".'**
  String get adminNotesPrefixHint;

  /// No description provided for @adminPasteListHint.
  ///
  /// In en, this message translates to:
  /// **'https://archive.org/.../E01.mp4\nhttps://archive.org/.../E02.mp4\n# comment skipped\nhttps://archive.org/.../E03.mp4'**
  String get adminPasteListHint;

  /// No description provided for @adminPasteNote.
  ///
  /// In en, this message translates to:
  /// **'💡 Blank lines & # comments are skipped. Episode auto-increments from the value above.'**
  String get adminPasteNote;

  /// No description provided for @adminMoreEntries.
  ///
  /// In en, this message translates to:
  /// **'+ {count} more entries'**
  String adminMoreEntries(int count);

  /// No description provided for @searchHeader.
  ///
  /// In en, this message translates to:
  /// **'Search something —'**
  String get searchHeader;

  /// No description provided for @searchFilterYear.
  ///
  /// In en, this message translates to:
  /// **'Release year'**
  String get searchFilterYear;

  /// No description provided for @searchFilterSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get searchFilterSeason;

  /// No description provided for @searchNoResultsQuery.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\".'**
  String searchNoResultsQuery(String query);

  /// No description provided for @searchNoResultsGenre.
  ///
  /// In en, this message translates to:
  /// **'No anime in genre {genres}.'**
  String searchNoResultsGenre(String genres);

  /// No description provided for @searchNoResultsQueryGenre.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\" + genre {genres}.'**
  String searchNoResultsQueryGenre(String query, String genres);

  /// No description provided for @commonAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get commonAbout;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @detailRelated.
  ///
  /// In en, this message translates to:
  /// **'Related Anime'**
  String get detailRelated;

  /// No description provided for @detailRecommended.
  ///
  /// In en, this message translates to:
  /// **'You might like'**
  String get detailRecommended;

  /// No description provided for @detailMetricDuration.
  ///
  /// In en, this message translates to:
  /// **'DURATION'**
  String get detailMetricDuration;

  /// No description provided for @detailAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get detailAddToList;

  /// No description provided for @detailChangeStatus.
  ///
  /// In en, this message translates to:
  /// **'Change status'**
  String get detailChangeStatus;

  /// No description provided for @detailRemoveFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get detailRemoveFromList;

  /// No description provided for @discussionPosted.
  ///
  /// In en, this message translates to:
  /// **'Discussion posted'**
  String get discussionPosted;

  /// No description provided for @discussionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Discussion deleted'**
  String get discussionDeleted;

  /// No description provided for @scheduleToday.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get scheduleToday;

  /// No description provided for @scheduleTimezone.
  ///
  /// In en, this message translates to:
  /// **'WIB zone'**
  String get scheduleTimezone;

  /// No description provided for @scheduleHiatus.
  ///
  /// In en, this message translates to:
  /// **'On hiatus'**
  String get scheduleHiatus;

  /// No description provided for @scheduleFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get scheduleFinished;

  /// No description provided for @scheduleWaiting.
  ///
  /// In en, this message translates to:
  /// **'Awaiting new episode'**
  String get scheduleWaiting;

  /// No description provided for @scheduleAired.
  ///
  /// In en, this message translates to:
  /// **'Aired'**
  String get scheduleAired;

  /// No description provided for @profileStatTitles.
  ///
  /// In en, this message translates to:
  /// **'titles'**
  String get profileStatTitles;

  /// No description provided for @profileStatHours.
  ///
  /// In en, this message translates to:
  /// **'hrs'**
  String get profileStatHours;

  /// No description provided for @profileStatFavorites.
  ///
  /// In en, this message translates to:
  /// **'favorites'**
  String get profileStatFavorites;

  /// No description provided for @editPassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get editPassword;

  /// No description provided for @commonUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get commonUpdate;

  /// No description provided for @commonChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get commonChange;

  /// No description provided for @wpLoginToStart.
  ///
  /// In en, this message translates to:
  /// **'Log in to start a watch party.'**
  String get wpLoginToStart;

  /// No description provided for @wpStarted.
  ///
  /// In en, this message translates to:
  /// **'Party started — invite friends!'**
  String get wpStarted;

  /// No description provided for @wpStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to start party: {error}'**
  String wpStartFailed(String error);

  /// No description provided for @wpChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking watch party...'**
  String get wpChecking;

  /// No description provided for @wpTitle.
  ///
  /// In en, this message translates to:
  /// **'Watch Party'**
  String get wpTitle;

  /// No description provided for @wpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Watch with friends, real-time chat'**
  String get wpSubtitle;

  /// No description provided for @wpStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start Watch Party'**
  String get wpStartButton;

  /// No description provided for @wpStartOwn.
  ///
  /// In en, this message translates to:
  /// **'Start your own party'**
  String get wpStartOwn;

  /// No description provided for @authLoginRequired.
  ///
  /// In en, this message translates to:
  /// **'Email and password are required'**
  String get authLoginRequired;

  /// No description provided for @authLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get authLoginFailed;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to watch together + discuss'**
  String get authLoginSubtitle;

  /// No description provided for @authGuestContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue without login (guest mode)'**
  String get authGuestContinue;

  /// No description provided for @authGuestNote.
  ///
  /// In en, this message translates to:
  /// **'Guest mode: browse + watch, but no\nWatch Party / Discussion / My List.'**
  String get authGuestNote;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get authPasswordMismatch;

  /// No description provided for @authRegisterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account created — welcome!'**
  String get authRegisterSuccess;

  /// No description provided for @authRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Register failed'**
  String get authRegisterFailed;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create new account'**
  String get authCreateAccount;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Free. Used for Watch Party + Discussion.'**
  String get authRegisterSubtitle;

  /// No description provided for @authHintMin3.
  ///
  /// In en, this message translates to:
  /// **'min 3 characters'**
  String get authHintMin3;

  /// No description provided for @authHintMin6.
  ///
  /// In en, this message translates to:
  /// **'min 6 characters'**
  String get authHintMin6;

  /// No description provided for @authHintRepeatPw.
  ///
  /// In en, this message translates to:
  /// **'repeat password'**
  String get authHintRepeatPw;

  /// No description provided for @authAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get authAgreePrefix;

  /// No description provided for @authTos.
  ///
  /// In en, this message translates to:
  /// **'Terms & Conditions'**
  String get authTos;

  /// No description provided for @authPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacy;

  /// No description provided for @authReadTos.
  ///
  /// In en, this message translates to:
  /// **'Read ToS'**
  String get authReadTos;

  /// No description provided for @authReadPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Read Privacy'**
  String get authReadPrivacy;

  /// No description provided for @settingsNotifEpisodes.
  ///
  /// In en, this message translates to:
  /// **'New episode alerts'**
  String get settingsNotifEpisodes;

  /// No description provided for @notifEpisodeTitle.
  ///
  /// In en, this message translates to:
  /// **'New episode!'**
  String get notifEpisodeTitle;

  /// No description provided for @notifEpisodeBody.
  ///
  /// In en, this message translates to:
  /// **'Episode {ep} of {title} is now airing'**
  String notifEpisodeBody(int ep, String title);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
