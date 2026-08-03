import '../../domain/models/legal_section.dart';
import 'app_strings.dart';

/// Structured copy for the three static info documents plus the FAQ —
/// broken into headings/paragraphs/bullets so [LegalInfoScreen] and
/// [FaqScreen] can render real typographic hierarchy instead of one long
/// block of plain text.
class LegalContent {
  LegalContent._();

  static const String lastUpdated = 'Last updated: August 2026';

  static const String privacyIntro =
      'TripNest PH ("we", "our", "the app") helps you discover tourist spots, restaurants, and festivals across the Philippines, plan trips with AI assistance, and lets you save favorites, write reviews, tag trip photos, and manage a business or tourism office listing.';

  static const List<LegalSection> privacySections = [
    LegalSection(
      heading: 'Information we collect',
      bullets: [
        'Account details you provide when you register: name, email address, and profile photo.',
        'Content you create: favorites, saved itineraries, expense entries you log for a trip, reviews, ratings, and photos you attach to reviews or trip photos.',
        'Location data you choose to share: your approximate current location (for "Nearby You" recommendations) and, when present in a photo\'s file, the GPS coordinates and timestamp of trip photos you upload to "My Photos".',
        'A push-notification token, used only to deliver alerts you haven\'t turned off.',
        'Your travel preferences and favorite categories, used to personalize recommendations and AI suggestions.',
        'If you register a business or hold an LGU/admin role: your business name, category, contact details, and the province you\'re assigned to.',
      ],
    ),
    LegalSection(
      heading: 'How we use it',
      paragraph:
          'Your data is used only to run the app\'s features described above — personalizing recommendations, syncing your favorites, itineraries, and expenses across sessions, matching trip photos to the place you took them, and showing your reviews to other users. We do not sell your personal information to third parties.',
    ),
    LegalSection(
      heading: 'AI features and third-party services',
      paragraph:
          'When you use the AI Travel Assistant or AI Trip Planner, your messages and trip details are sent to our servers, which relay them to a third-party AI provider to generate a response — your data isn\'t stored by that provider beyond what\'s needed to answer your request. Location-based searches (Explore, Search, Nearby You, trip route directions) are relayed the same way to Google\'s Places and Routes APIs. In every case, the request is proxied through our own servers — the app never sends your data to these providers directly, and no third-party API key is ever stored on your device.',
    ),
    LegalSection(
      heading: 'Where it\'s stored',
      paragraph:
          'Account data, favorites, itineraries, expenses, reviews, and trip photos are stored securely in Firebase (Google Cloud) under your account and protected by access rules that only allow you to read and write your own data. Photos you upload are stored in Firebase Storage. Saved itineraries can also be cached on your own device so they\'re viewable offline.',
    ),
    LegalSection(
      heading: 'Business and tourism office (LGU) accounts',
      paragraph:
          'If you register a business listing, the business name, category, description, contact details, and photos you submit are reviewed by our tourism partners and, once approved, shown publicly to travelers on the listing page — don\'t include personal information there that you don\'t want made public. Local government (LGU) tourism accounts can only manage and view analytics for the single province they\'re assigned to.',
    ),
    LegalSection(
      heading: 'Your choices',
      paragraph:
          'You can edit or delete your profile information, remove any review, trip photo, or saved itinerary, report a review you believe is fake or abusive, and disable location or notification permissions at any time from Settings or your device\'s system settings — Emergency Alerts and Maintenance Notices can\'t be turned off since they\'re safety-critical. Deleting your account removes your personal data from our records.',
    ),
    LegalSection(heading: 'Contact us', paragraph: 'Questions about this policy can be sent to privacy@tripnestph.app.'),
  ];

  static const String termsIntro = 'By creating an account or using TripNest PH, you agree to these terms.';

  static const List<LegalSection> termsSections = [
    LegalSection(
      heading: 'Using the app',
      paragraph:
          'TripNest PH is a travel discovery and planning tool. It is not a booking platform — the app does not process payments, reservations, or bookings on your behalf. Contact details, links, and pricing shown for destinations, restaurants, festivals, and business listings are provided for reference and may change without notice; always confirm details directly with the venue or organizer before traveling.',
    ),
    LegalSection(
      heading: 'Your account',
      paragraph:
          'You\'re responsible for keeping your login credentials secure and for the accuracy of the information you provide. You must be at least 13 years old to create an account.',
    ),
    LegalSection(
      heading: 'User-generated content',
      paragraph:
          'When you post a review, rating, trip photo, or other content, you confirm it\'s your own honest experience and that you have the right to share it, including any location data attached to a photo. We may remove content that is abusive, misleading, or violates these terms, and other users can report content they believe does the same.',
    ),
    LegalSection(
      heading: 'AI-assisted features',
      paragraph:
          'Itinerary suggestions and answers from the AI Travel Assistant and AI Trip Planner are generated by a third-party AI model and provided for inspiration only. They are not guarantees of availability, pricing, weather, or safety conditions, and may occasionally be inaccurate — always verify details before finalizing travel plans.',
    ),
    LegalSection(
      heading: 'Expense splitting',
      paragraph:
          'The expense-splitting tool inside a saved itinerary is a coordination aid for tracking who owes what among your travel companions — it does not move, hold, or transfer any money. Settling amounts with your companions happens entirely outside the app.',
    ),
    LegalSection(
      heading: 'Business and tourism office (LGU) listings',
      paragraph:
          'Business listings are self-submitted and subject to review and approval by our local tourism partners before appearing publicly, and may be suspended or removed if information is found to be false, misleading, or in violation of these terms. LGU tourism office accounts are provisioned by TripNest PH administrators and scoped to a single province.',
    ),
    LegalSection(
      heading: 'Availability',
      paragraph:
          'We aim to keep TripNest PH available and accurate, but the app is provided "as is" without warranties of any kind. We may update, suspend, or discontinue features at any time.',
    ),
    LegalSection(
      heading: 'Changes to these terms',
      paragraph: 'We may update these terms as the app evolves. Continued use after a change means you accept the updated terms.',
    ),
    LegalSection(heading: 'Contact us', paragraph: 'Questions about these terms can be sent to support@tripnestph.app.'),
  ];

  static const String aboutIntro =
      'TripNest PH is your companion for exploring the Philippines — from postcard-famous beaches to hidden waterfalls, family-run carinderias to festival street parties.';

  static const List<String> aboutFeatures = [
    'Browse tourist spots, restaurants, and festivals — curated by local tourism offices and backed by live Google Places data for even more to discover.',
    'Search and filter by province, category, and rating.',
    'Save your favorite places, and get AI-assisted trip planning — chat with the AI Travel Assistant or generate a full day-by-day itinerary.',
    'Save itineraries for offline access, and split trip expenses with your travel companions.',
    'Rate and review places you\'ve visited, with photos, and tag your trip photos to the exact place you took them.',
    'Business owners can list and manage their own accommodations, restaurants, tours, and shops.',
    'Local tourism offices (LGUs) can manage their province\'s listings and see local engagement analytics.',
  ];

  static const String aboutClosing =
      'Built for Filipino travelers and visitors alike, ${AppStrings.appName} is designed to make discovering the country\'s 7,000+ islands feel a little more personal.';

  static const String appVersion = 'Version 1.0.0';
  static const String aboutFooter = 'Made with care in the Philippines.';

  /// Canonical display order for FAQ section headers — categories not in
  /// this list (there shouldn't be any) sort after everything here.
  static const List<String> faqCategoryOrder = [
    'Getting Started',
    'Account & Profile',
    'Trip Planning & AI',
    'Reviews & Photos',
    'Privacy & Location',
    'Business & LGU Accounts',
    'Support',
  ];

  static const List<FaqItem> faq = [
    // Getting Started
    FaqItem(
      category: 'Getting Started',
      question: 'Is TripNest PH free to use?',
      answer: 'Yes. Browsing destinations, saving favorites, writing reviews, and using the AI trip planner are all free.',
    ),
    FaqItem(
      category: 'Getting Started',
      question: 'Do I need an account to use the app?',
      answer:
          'You can browse destinations, restaurants, and festivals without one. You\'ll need an account to save favorites, write reviews, or build and save itineraries.',
    ),
    FaqItem(
      category: 'Getting Started',
      question: 'Can I book hotels, restaurants, or festival tickets through the app?',
      answer:
          'Not directly — TripNest PH is a discovery and planning tool, not a booking platform. Contact details, links, and pricing shown are for reference; always confirm with the venue or organizer directly before traveling.',
    ),
    FaqItem(
      category: 'Getting Started',
      question: 'How do I find places near me?',
      answer:
          'The "Nearby You" section on Home shows destinations and restaurants closest to your current location, once you\'ve allowed location access — the closest place always shows first.',
    ),
    FaqItem(
      category: 'Getting Started',
      question: 'How do I search for a specific place?',
      answer:
          'Tap the search bar on Home or Explore and type a destination, restaurant, or festival name. You can also filter by province and rating.',
    ),
    FaqItem(
      category: 'Getting Started',
      question: 'Why do I see places in Explore or Search that I don\'t recognize?',
      answer:
          'Alongside places curated by local tourism offices, TripNest PH pulls in live results from Google Places so you always have more to discover — even spots that haven\'t been added to a province\'s official guide yet.',
    ),
    // Account & Profile
    FaqItem(
      category: 'Account & Profile',
      question: 'How do I change my profile photo or name?',
      answer: 'Go to Profile → Edit Profile to update your name and photo. If you signed in with Google, your Google profile photo is used by default.',
    ),
    FaqItem(
      category: 'Account & Profile',
      question: 'Can I change the app\'s color theme?',
      answer: 'Yes — go to Settings → Theme to choose from several color presets, each available in both light and dark mode.',
    ),
    FaqItem(
      category: 'Account & Profile',
      question: 'I forgot my password. What do I do?',
      answer: 'On the login screen, tap "Forgot Password" and enter your registered email — we\'ll send you a reset link.',
    ),
    FaqItem(
      category: 'Account & Profile',
      question: 'How do I delete my account?',
      answer:
          'Go to Settings → Delete Account, or email support@tripnestph.app from your registered email address to request it. This removes your personal data, favorites, itineraries, and reviews from our records.',
    ),
    FaqItem(
      category: 'Account & Profile',
      question: 'Can I use TripNest PH on more than one device?',
      answer: 'Yes — sign in with the same account and your favorites, itineraries, and reviews stay in sync across devices.',
    ),
    // Trip Planning & AI
    FaqItem(
      category: 'Trip Planning & AI',
      question: 'How accurate are the AI-generated itineraries?',
      answer:
          'They\'re a starting point for inspiration, built from your interests and trip details. They\'re not guarantees of availability, pricing, weather, or safety — always double-check details before finalizing plans.',
    ),
    FaqItem(
      category: 'Trip Planning & AI',
      question: 'How do I save a destination or itinerary?',
      answer:
          'Tap the bookmark icon on any destination, restaurant, or festival card to save it to your favorites. Itineraries generated by the AI Planner can be saved from the itinerary screen and revisited anytime under Saved.',
    ),
    FaqItem(
      category: 'Trip Planning & AI',
      question: 'Can I view a saved itinerary without internet access?',
      answer: 'Yes — saved itineraries can be made available offline, so you can check your plans even without a connection while traveling.',
    ),
    FaqItem(
      category: 'Trip Planning & AI',
      question: 'Can I split trip costs with my travel companions?',
      answer:
          'Yes — open a saved itinerary\'s expense tracker to log costs, choose who they\'re split between, and see who owes what. It\'s for tracking only; TripNest PH doesn\'t transfer or hold any money.',
    ),
    FaqItem(
      category: 'Trip Planning & AI',
      question: 'Can I edit an itinerary after the AI generates it?',
      answer: 'Yes — you can regenerate it with different preferences, or remove individual stops before saving it.',
    ),
    FaqItem(
      category: 'Trip Planning & AI',
      question: 'Can I have more than one conversation with the AI Travel Assistant?',
      answer: 'Yes — open the chat menu to start a new conversation or switch between your saved chats, each kept separate.',
    ),
    FaqItem(
      category: 'Trip Planning & AI',
      question: 'What can I ask the AI Travel Assistant?',
      answer:
          'Anything trip-related — recommendations by province or interest, festival timing, budget-friendly ideas, or help refining a saved itinerary. Tap the chat icon on any tab to open it.',
    ),
    FaqItem(
      category: 'Trip Planning & AI',
      question: 'Does the AI Planner know real-time prices or availability?',
      answer: 'No — it doesn\'t have live pricing or booking data. Treat its suggestions as a planning starting point and confirm details directly with venues.',
    ),
    // Reviews & Photos
    FaqItem(
      category: 'Reviews & Photos',
      question: 'Can I edit or delete a review I posted?',
      answer: 'Yes — open the review from your Profile and you\'ll find options to edit or delete it there.',
    ),
    FaqItem(
      category: 'Reviews & Photos',
      question: 'Can I add photos to my review?',
      answer: 'Yes — when writing a review you can attach photos from your device to show other travelers what to expect.',
    ),
    FaqItem(
      category: 'Reviews & Photos',
      question: 'What is "My Photos" and how is it different from review photos?',
      answer:
          'My Photos is your personal trip photo album, separate from reviews. Upload a photo taken with location data and the app automatically matches it to the destination, restaurant, or nearby place where it was taken.',
    ),
    FaqItem(
      category: 'Reviews & Photos',
      question: 'How do I report a review?',
      answer: 'Open the review and tap the report/flag icon, choose a reason (spam, fake, inappropriate, or other), and our moderators will review it.',
    ),
    FaqItem(
      category: 'Reviews & Photos',
      question: 'Why was my review removed?',
      answer: 'Reviews that are abusive, misleading, or unrelated to a genuine visit may be removed to keep listings trustworthy for other travelers.',
    ),
    FaqItem(
      category: 'Reviews & Photos',
      question: 'I found incorrect information on a listing. What should I do?',
      answer:
          'Please email support@tripnestph.app with the destination/restaurant/festival name and what\'s wrong — our team reviews and corrects listings regularly.',
    ),
    // Privacy & Location
    FaqItem(
      category: 'Privacy & Location',
      question: 'Why does the app ask for my location?',
      answer:
          'Location is used for the "Nearby You" recommendations on Home and to sort nearby results by actual distance. You can turn this off anytime in Settings without losing any other functionality.',
    ),
    FaqItem(
      category: 'Privacy & Location',
      question: 'Does TripNest PH sell my data?',
      answer: 'No. Your data is used only to run the app\'s own features — see our Privacy Policy for the full details, including how AI and location features work.',
    ),
    FaqItem(
      category: 'Privacy & Location',
      question: 'Can I turn off notifications?',
      answer:
          'Yes — go to Settings and toggle Notifications off, or turn off individual categories like festival alerts and travel tips. Emergency Alerts and Maintenance Notices can\'t be turned off since they\'re safety-critical.',
    ),
    FaqItem(
      category: 'Privacy & Location',
      question: 'Where is my data stored?',
      answer: 'Your account data, favorites, itineraries, expenses, and reviews are stored securely in Firebase (Google Cloud), protected by access rules scoped to your account.',
    ),
    FaqItem(
      category: 'Privacy & Location',
      question: 'Does the AI Travel Assistant see my personal data?',
      answer:
          'It sees the message you send it, along with general context like real destinations and provinces it can recommend. Your requests are relayed through our own servers to the AI provider — never sent from your device directly.',
    ),
    // Business & LGU Accounts
    FaqItem(
      category: 'Business & LGU Accounts',
      question: 'How do I list my business on TripNest PH?',
      answer:
          'Email support@tripnestph.app to request Business Owner access. Once granted, you\'ll see an invite banner on your Profile — accept it, then submit your business details, category, and photos under "My Business" for review.',
    ),
    FaqItem(
      category: 'Business & LGU Accounts',
      question: 'How long does business listing approval take?',
      answer: 'Review times vary, but you\'ll be notified in-app as soon as your listing is approved, rejected, or suspended, along with the reason if it wasn\'t approved.',
    ),
    FaqItem(
      category: 'Business & LGU Accounts',
      question: 'Can I see how my business listing is performing?',
      answer: 'Yes — once approved, your business page shows your average rating, review count, and recent reviews from travelers.',
    ),
    FaqItem(
      category: 'Business & LGU Accounts',
      question: 'I\'m from a local tourism office (LGU). How do I get access?',
      answer:
          'LGU tourism office accounts are provisioned by TripNest PH administrators for a specific province. Email support@tripnestph.app to request access for your office.',
    ),
    // Support
    FaqItem(
      category: 'Support',
      question: 'The app is showing an error or won\'t load. What should I do?',
      answer: 'Check your internet connection first, then try closing and reopening the app. If it still doesn\'t work, email support@tripnestph.app with a description of what happened.',
    ),
    FaqItem(
      category: 'Support',
      question: 'How do I contact support?',
      answer: 'Email support@tripnestph.app for general help, or privacy@tripnestph.app for privacy-specific questions. We aim to reply within a few business days.',
    ),
    FaqItem(
      category: 'Support',
      question: 'Can I suggest a destination, restaurant, or festival to add?',
      answer: 'Yes — email support@tripnestph.app with details and photos if you have them. Suggestions are reviewed by our local tourism partners.',
    ),
  ];
}
