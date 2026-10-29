const _strings = <String, Map<String, String>>{
  'en': {
    'home': 'Home',
    'plan': 'Plan',
    'insights': 'Insights',
    'hub': 'Hub',
    'settings': 'Settings',
    'goodMorning': 'Good morning',
    'goodAfternoon': 'Good afternoon',
    'goodEvening': 'Good evening',
    'balance': 'Total net balance',
    'thisMonth': 'This month',
    'income': 'Income',
    'expenses': 'Expenses',
    'net': 'Net savings',
    'accounts': 'Accounts',
    'addAccount': 'Add account',
    'upcomingBills': 'Upcoming bills',
    'seeAll': 'See all',
    'markPaid': 'Mark paid',
    'recent': 'Recent transactions',
    'addFirst': 'Add your first transaction',
    'emptyHome': 'Your money story starts here.',
    'noAccounts': 'Add an account to see your balances.',
    'add': 'Add',
    'inbox': 'SMS inbox',
    'pending': 'Pending',
    'confirmed': 'Confirmed',
    'dismissed': 'Dismissed',
    'review': 'Review',
    'nothingYet': 'You’re all caught up',
    'smsEmpty': 'Bank messages you choose to review will show up here.',
    'confirm': 'Confirm',
    'dismiss': 'Dismiss',
    'original': 'Show original message',
    'expense': 'Expense',
    'transfer': 'Transfer',
    'save': 'Save',
    'amount': 'Amount',
    'description': 'Description',
    'account': 'Account',
    'category': 'Category',
    'today': 'Today',
    'goals': 'Goals',
    'bills': 'Bills',
    'newGoal': 'New goal',
    'newBill': 'Add bill',
    'deposit': 'Deposit',
    'create': 'Create',
    'target': 'Target amount',
    'goalName': 'What are you saving for?',
    'suggestions': 'Suggestions',
    'whereMoneyWent': 'Where your money went',
    'notEnoughData': 'Not enough data yet',
    'notEnoughHint': 'Add a few transactions to uncover your money patterns.',
    'healthScore': 'Financial health',
    'noData': 'No activity yet',
    'noDataHint': 'Add transactions to get a clearer picture of your money.',
    'tools': 'Your money tools',
    'settingsTitle': 'Settings',
    'language': 'Language',
    'appearance': 'Appearance',
    'darkMode': 'Dark theme',
    'sound': 'Sound effects',
    'haptics': 'Vibration feedback',
    'hideBalances': 'Hide balances',
    'ethiopianCalendar': 'Ethiopian calendar',
    'testChime': 'Test chime',
    'testSms': 'Test SMS',
    'privacy': 'Your money stays on this device.',
    'privacySub':
        'BirrWise works offline. Your financial data is stored privately on this phone.',
    'saved': 'Saved',
    'expenseAdded': 'Expense saved',
    'incomeAdded': 'Income saved',
    'accountName': 'Account name',
    'institution': 'Institution',
    'openingBalance': 'Opening balance',
    'maskedNumber': 'Last digits (optional)',
    'transactions': 'Transactions',
    'search': 'Search transactions',
    'all': 'All',
    'cash': 'Cash',
    'food_groceries': 'Food & groceries',
    'transport': 'Transport',
    'utilities': 'Utilities',
    'rent': 'Rent',
    'airtime_data': 'Airtime & data',
    'health': 'Health',
    'education': 'Education',
    'family_support': 'Family support',
    'equb_iddir': 'Equb & Iddir',
    'shopping': 'Shopping',
    'entertainment': 'Entertainment',
    'business': 'Business',
    'salary': 'Salary',
    'gift': 'Gift',
    'other': 'Other',
    'clear': 'Clear',
    'due': 'Due',
    'paid': 'Paid',
    'monthly': 'Monthly',
    'noGoals': 'Make room for what matters.',
    'noBills': 'Keep upcoming payments in one calm place.',
    'addGoal': 'Create a savings goal',
    'addBill': 'Add your first bill',
    'high': 'High confidence',
    'check': 'Please check',
    'incomeDirection': 'Money in',
    'expenseDirection': 'Money out',
    'bankSmsAutomation': 'Auto-track bank SMS',
    'bankSmsAutomationSub':
        'Read trusted bank alerts on this device to track clear transactions automatically.',
    'smsPermissionMissing':
        'SMS access is off. Allow inbox and incoming-message access to enable automation.',
    'smsSyncFailed':
        'Bank alerts could not be scanned. Reopen the app or try again.',
    'smsAndroidOnly': 'Automatic SMS tracking is available on Android only.',
    'smsScanning': 'Checking supported bank alerts on this device…',
    'smsAutomationOff': 'Off. BirrWise is not reading your messages.',
    'smsAutomationReady':
        'On. Only supported bank senders are checked; new alerts sync when you open BirrWise.',
    'smsHistoryScanned':
        'Your existing bank alerts have been scanned on this device.',
    'smsScanNow': 'Scan bank alerts now',
    'smsPermissionTitle': 'Allow on-device bank alert scanning?',
    'smsPermissionBody':
        'Android requires SMS access to scan messages. BirrWise checks only supported bank senders and keeps messages on this phone. Each clear alert is added automatically to the account for its bank, which BirrWise creates if needed, and the account follows the balance your bank reports. Unclear alerts stay in review; unrelated messages are ignored.',
    'smsPermissionContinue': 'Continue',
    'smsImportSummary':
        'Checked {scanned} bank alerts: {recognized} recognized, {imported} added, {pending} for review, {ignored} not recognized, {duplicates} already seen.',
    'smsNoBankSenders':
        'No messages from a supported bank sender were found. Check that bank alerts are in your SMS inbox and try again.',
    'smsHistoryOnce':
        'Bank alerts from the last 30 days are checked once when you turn this on and added to your accounts. Each account then matches the balance your bank last reported.',
    'undo': 'Undo',
    'yesterday': 'Yesterday',
    'cancel': 'Cancel',
    'transactionRemoved': 'Transaction removed',
    'smsDismissedToast': 'Message dismissed',
    'restore': 'Restore',
    'invalidOpeningBalance': 'Enter a valid opening balance.',
    'invalidAmount': 'Enter a valid amount.',
    'showBalances': 'Show balances',
    'balanceHiddenSpoken': 'Balance hidden',
    'chooseTwoAccounts': 'Choose two different accounts.',
    'toAccount': 'To account',
    'fromAccount': 'From account',
    'adjustment': 'Balance adjustment',
    'transactionConfirmed': 'Transaction confirmed',
    'alreadyRecorded': 'This transaction was already recorded',
    'smsBalanceDiffers':
        'Confirmed. The bank reports {balance} for this account.',
    'matchBalance': 'Match',
    'olderThanTracking':
        'This alert arrived before this account was added or before tracking was turned on. Confirming it will change the account balance.',
    'confirmAll': 'Confirm all',
    'confirmAllTitle': 'Confirm these messages?',
    'confirmAllBody':
        'Add {count} high-confidence messages, each to the account for its bank.',
    'confirmAllDone': '{count} transactions confirmed.',
    'confirmAllSkipped':
        '{count} skipped: add an account for that bank first.',
    'manageAccounts': 'Manage your accounts',
    'correctBalance': 'Correct balance',
    'currentBalance': 'Current balance',
    'correctBalanceHint':
        'Enter the balance your bank or wallet shows now. The difference is saved as an adjustment and is not counted as income or spending.',
    'balanceMatches': 'The balance already matches.',
    'balanceCorrected': 'Balance corrected',
    'archive': 'Archive',
    'unarchive': 'Restore',
    'archived': 'Archived',
    'monthlySnapshot': 'Monthly snapshot',
    'scoreHowMade': 'How your score is made',
    'scoreNeedsAttention': 'Needs attention',
    'scoreFair': 'Fair',
    'scoreGood': 'Good',
    'scoreExcellent': 'Excellent',
    'factorSavings': 'Savings rate this month',
    'factorBills': 'Bills paid on time',
    'factorEmergency': 'Emergency fund',
    'factorStability': 'Spending stability',
    'scoreNotEnoughHint':
        'Record at least 3 transactions this month, including your income, to see a score.',
    'scoreWeakest': 'Most room to improve: {factor}.',
    'scoreAllStrong': 'Every part of your score is strong this month.',
    'recTopCategory':
        '{category} is {percent}% of your spending this month. A small cut there goes furthest.',
    'recBillsSoon': 'Bills due in the next 3 days: {count}.',
    'recLowSavings':
        'You kept {percent}% of your income this month. Aim for at least 10%.',
    'recOldPending':
        'Some bank messages have waited more than 3 days for review.',
    'recAllGood': 'Nothing needs attention this month. Keep going.',
    'reviewBills': 'Review bills',
    'businessEntry':
        'Business (shop) money',
    'testCash':
        'Cash',
    'testGoal':
        'Goal',
    'budget':
        'Budget',
    'loans':
        'Loans',
    'monthlyTarget':
        'Monthly target',
    'edit':
        'Edit',
    'targetIncome':
        'Income target',
    'plannedSpending':
        'Planned spending',
    'categoryBudgets':
        'Category budgets',
    'noBudgets':
        'No budgets yet. Add a monthly limit for a category to track it here.',
    'setBudget':
        'Set budget',
    'monthlyLimit':
        'Monthly limit',
    'remove':
        'Remove',
    'loansHint':
        'Keep track of money you lent to people or borrowed from them.',
    'addLoan':
        'Add a loan',
    'owedToYou':
        'Owed to you',
    'youOwe':
        'You owe',
    'settled':
        'Settled',
    'lent':
        'Lent',
    'borrowed':
        'Borrowed',
    'left':
        'left',
    'recordPayment':
        'Record a repayment',
    'markSettled':
        'Mark settled',
    'delete':
        'Delete',
    'amountLabel':
        'Amount',
    'personName':
        'Name',
    'loanInvalid':
        'Enter a name and an amount.',
    'csvSub':
        'Save the ledger as a spreadsheet',
    'backup':
        'Backup',
    'backupSub':
        'Save or restore a backup file',
    'merchantMode':
        'Shop mode',
    'merchantModeSub':
        'Tag business money separately from household spending.',
    'saveBackup':
        'Save a backup file',
    'restoreBackup':
        'Restore a backup',
    'backupWarning':
        'Backup files are not encrypted. Keep them somewhere private.',
    'restoreConfirm':
        'Everything in BirrWise will be replaced by the backup. Your settings and PIN stay as they are.',
    'restoreDone':
        'Backup restored.',
    'restoreInvalid':
        'That file is not a BirrWise backup. Nothing was changed.',
    'fileFailed':
        'The file could not be used. Try again.',
    'fileSaved':
        'File saved.',
    'monitoredBanks':
        'Banks and wallets to watch',
    'monitoredBanksCount':
        '{count} selected',
    'security':
        'Security',
    'pinLock':
        'App lock (PIN)',
    'pinOn':
        'On. BirrWise asks for your PIN when you come back to it.',
    'pinOff':
        'Off',
    'privacyPolicy':
        'Privacy policy',
    'eraseAll':
        'Erase all data',
    'pinEnter':
        'Enter your 4-digit PIN',
    'pinForgetWarning':
        'If you forget it, you will have to clear the BirrWise storage in Android settings, which erases everything.',
    'pinRemoveConfirm':
        'Turn off the PIN lock?',
    'turnOff':
        'Turn off',
    'eraseConfirm':
        'This erases every account, transaction, plan and setting on this phone and turns SMS tracking off. It cannot be undone. Save a backup first if you may need it.',
    'eraseEverything':
        'Erase everything',
    'erased':
        'All BirrWise data was erased.',
    'privacyPolicyBody':
        '1. Everything stays on this phone. BirrWise has no account, no server and no analytics, and it sends nothing anywhere.\n\n2. SMS access is used only to find transactions in alerts from the banks and wallets you keep ticked in Settings. Personal messages are never read or saved.\n\n3. Clear alerts are added to your accounts automatically; unclear ones wait for you in the SMS inbox. Turning tracking off in Settings stops it at once.\n\n4. Backups and CSV exports are saved only where you choose. They are not encrypted, so keep those files private.\n\n5. Android backup is turned off for BirrWise data. Erase all data in Settings removes everything.\n\n6. Google Play restricts SMS permissions, so this build is meant to be installed directly.',
    'understood':
        'I understand',
    'pinWrong':
        'Incorrect PIN. Try again.',
    'welcomeTitle':
        'Welcome to BirrWise',
    'welcomeSubtitle':
        'Your private, offline money companion for Ethiopia.',
    'chooseLanguage':
        'Choose your language',
    'privacyFirstHeading':
        'Offline and private',
    'privacyFirstBody':
        'Your bank and wallet messages never leave this phone. Everything is worked out on your device.',
    'cashFlowTrend':
        'Income and spending, last 4 months',
    'editAmount':
        'Change amount',
    'pinAgain':
        'Enter it again',
    'pinMismatch':
        'The two PINs are different.',
    'shopTag':
        'Shop',
    'banksTitle':
        'Which banks and wallets are yours?',
    'banksBody':
        'BirrWise reads alerts only from the ones you tick. Alerts from the others are ignored, and anything already added from them is taken out. You can change this later in Settings.',
    'alertsFound':
        'Alerts found: {count}',
    'done':
        'Done',
  },
  'am': {
    'home': 'ዋና ገጽ',
    'plan': 'ዕቅድ',
    'insights': 'ግንዛቤ',
    'hub': 'መሳሪያዎች',
    'settings': 'ቅንብሮች',
    'goodMorning': 'እንደምን አደሩ',
    'goodAfternoon': 'እንደምን ዋሉ',
    'goodEvening': 'እንደምን አመሹ',
    'balance': 'ጠቅላላ ቀሪ ሂሳብ',
    'thisMonth': 'በዚህ ወር',
    'income': 'ገቢ',
    'expenses': 'ወጪ',
    'net': 'የተጣራ ቁጠባ',
    'accounts': 'ሂሳቦች',
    'addAccount': 'ሂሳብ ጨምር',
    'upcomingBills': 'የሚመጡ ክፍያዎች',
    'seeAll': 'ሁሉንም እይ',
    'markPaid': 'ተከፍሏል',
    'recent': 'የቅርብ ግብይቶች',
    'addFirst': 'የመጀመሪያ ግብይትዎን ያክሉ',
    'emptyHome': 'የገንዘብ ጉዞዎ እዚህ ይጀምራል።',
    'noAccounts': 'ቀሪ ሂሳብዎን ለማየት ሂሳብ ያክሉ።',
    'add': 'ጨምር',
    'inbox': 'የኤስኤምኤስ ሳጥን',
    'pending': 'በመጠባበቅ ላይ',
    'confirmed': 'የተረጋገጡ',
    'dismissed': 'የተወገዱ',
    'review': 'ክለሳ',
    'nothingYet': 'ሁሉንም አይተዋል',
    'smsEmpty': 'ለመከለስ የመረጡት የባንክ መልዕክቶች እዚህ ይታያሉ።',
    'confirm': 'አረጋግጥ',
    'dismiss': 'አስወግድ',
    'original': 'ዋናውን መልዕክት አሳይ',
    'expense': 'ወጪ',
    'transfer': 'ዝውውር',
    'save': 'አስቀምጥ',
    'amount': 'መጠን',
    'description': 'መግለጫ',
    'account': 'ሂሳብ',
    'category': 'ምድብ',
    'today': 'ዛሬ',
    'goals': 'ግቦች',
    'bills': 'ክፍያዎች',
    'newGoal': 'አዲስ ግብ',
    'newBill': 'ክፍያ ጨምር',
    'deposit': 'ቁጠባ ጨምር',
    'create': 'ፍጠር',
    'target': 'የግብ መጠን',
    'goalName': 'ለምን እየቆጠቡ ነው?',
    'suggestions': 'ምክሮች',
    'whereMoneyWent': 'ገንዘብዎ የት እንደዋለ',
    'notEnoughData': 'እስካሁን በቂ መረጃ የለም',
    'notEnoughHint': 'የወጪ አጠቃቀምዎን ለማወቅ ጥቂት ግብይቶችን ያክሉ።',
    'healthScore': 'የገንዘብ ጤና',
    'noData': 'እስካሁን እንቅስቃሴ የለም',
    'noDataHint': 'የገንዘብዎን ሁኔታ ለማየት ግብይቶችን ያክሉ።',
    'tools': 'የገንዘብ መሳሪያዎች',
    'settingsTitle': 'ቅንብሮች',
    'language': 'ቋንቋ',
    'appearance': 'ገጽታ',
    'darkMode': 'ጨለማ ገጽታ',
    'sound': 'የድምፅ ውጤቶች',
    'haptics': 'የንዝረት ምላሽ',
    'hideBalances': 'ቀሪ ሂሳቦችን ደብቅ',
    'ethiopianCalendar': 'የኢትዮጵያ የቀን አቆጣጠር',
    'testChime': 'ድምፅ ሞክር',
    'testSms': 'ኤስኤምኤስ ሞክር',
    'privacy': 'ገንዘብዎ በዚህ ስልክ ላይ ብቻ ይቆያል።',
    'privacySub': 'BirrWise ያለ በይነመረብ ይሰራል። የገንዘብ መረጃዎ በዚህ ስልክ ውስጥ በግል ይቀመጣል።',
    'saved': 'ተቀምጧል',
    'expenseAdded': 'ወጪው ተቀምጧል',
    'incomeAdded': 'ገቢው ተቀምጧል',
    'accountName': 'የሂሳብ ስም',
    'institution': 'ተቋም',
    'openingBalance': 'መነሻ ቀሪ ሂሳብ',
    'maskedNumber': 'የመጨረሻ ቁጥሮች (አማራጭ)',
    'transactions': 'ግብይቶች',
    'search': 'ግብይት ፈልግ',
    'all': 'ሁሉም',
    'cash': 'ጥሬ ገንዘብ',
    'food_groceries': 'ምግብ እና ግሮሰሪ',
    'transport': 'ትራንስፖርት',
    'utilities': 'መገልገያዎች',
    'rent': 'ኪራይ',
    'airtime_data': 'የስልክ እና ዳታ',
    'health': 'ጤና',
    'education': 'ትምህርት',
    'family_support': 'የቤተሰብ ድጋፍ',
    'equb_iddir': 'እቁብ እና እድር',
    'shopping': 'ግዢ',
    'entertainment': 'መዝናኛ',
    'business': 'ንግድ',
    'salary': 'ደመወዝ',
    'gift': 'ስጦታ',
    'other': 'ሌላ',
    'clear': 'አጽዳ',
    'due': 'ቀነ ገደብ',
    'paid': 'ተከፍሏል',
    'monthly': 'በየወሩ',
    'noGoals': 'ለአስፈላጊው ነገር ቦታ ይፍጠሩ።',
    'noBills': 'የሚመጡ ክፍያዎችን በአንድ ቦታ ያደራጁ።',
    'addGoal': 'የቁጠባ ግብ ፍጠር',
    'addBill': 'የመጀመሪያ ክፍያ ጨምር',
    'high': 'ከፍተኛ እርግጠኝነት',
    'check': 'እባክዎ ያረጋግጡ',
    'incomeDirection': 'ገቢ',
    'expenseDirection': 'ወጪ',
    'bankSmsAutomation': 'የባንክ SMS በራስ-ሰር መከታተያ',
    'bankSmsAutomationSub': 'የተመረጡ የባንክ መልዕክቶችን በዚህ ስልክ ያንብቡ።',
    'smsPermissionMissing': 'የSMS ፈቃድ አልተሰጠም።',
    'smsSyncFailed': 'የባንክ መልዕክቶችን መፈተሽ አልተቻለም። እንደገና ይሞክሩ።',
    'smsAndroidOnly': 'የSMS በራስ-ሰር ክትትል በAndroid ላይ ብቻ ይገኛል።',
    'smsScanning': 'የተመረጡ የባንክ SMS መልዕክቶችን በዚህ ስልክ በመፈተሽ ላይ…',
    'smsAutomationOff': 'ጠፍቷል። BirrWise መልዕክቶችዎን አያነብም።',
    'smsAutomationReady': 'በርቷል። የባንክ መልዕክቶች በዚህ ስልክ ብቻ ይፈተሻሉ።',
    'smsHistoryScanned': 'ያሉት የባንክ መልዕክቶች በዚህ ስልክ ተፈትሸዋል።',
    'smsScanNow': 'የባንክ መልዕክቶችን አሁን ፈትሽ',
    'smsPermissionTitle': 'የባንክ መልዕክቶችን በዚህ ስልክ ፈትሽ?',
    'smsPermissionBody':
        'Android የSMS ፈቃድ ይፈልጋል። BirrWise የተመረጡ የባንክ ላኪዎችን ብቻ ይፈትሻል፤ መልዕክቶች ከዚህ ስልክ አይወጡም። ግልጽ መልዕክት ወደ ባንኩ ሂሳብ በራሱ ይመዘገባል፤ ሂሳብ ከሌለ ይፈጠራል፣ ቀሪ ሂሳቡም ባንኩ ከሚያሳውቀው ጋር ይስተካከላል። ግልጽ ያልሆኑ መልዕክቶች ለክለሳ ይቀመጣሉ፤ የማይዛመዱ መልዕክቶች ይተዋሉ።',
    'smsPermissionContinue': 'ቀጥል',
    'smsImportSummary':
        '{scanned} የባንክ መልዕክቶች ተፈትሸዋል: {recognized} ተለይተዋል፣ {imported} ተጨምረዋል፣ {pending} ክለሳ ይፈልጋሉ፣ {ignored} አልተለዩም፣ {duplicates} ቀድሞ ታይተዋል።',
    'smsNoBankSenders':
        'የተመረጠ የባንክ ላኪ መልዕክት አልተገኘም። የባንክ SMS በinbox ውስጥ መኖሩን ያረጋግጡና እንደገና ይሞክሩ።',
    'smsHistoryOnce':
        'ሲያበሩት ያለፉት 30 ቀናት የባንክ መልዕክቶች አንድ ጊዜ ተፈትሸው ወደ ሂሳቦችዎ ይጨመራሉ። ከዚያ እያንዳንዱ ሂሳብ ባንኩ በመጨረሻ ካሳወቀው ቀሪ ሂሳብ ጋር ይስተካከላል።',
    'undo': 'ቀልብስ',
    'yesterday': 'ትናንት',
    'cancel': 'ተወው',
    'transactionRemoved': 'ግብይቱ ተሰርዟል',
    'smsDismissedToast': 'መልዕክቱ ተወግዷል',
    'restore': 'መልስ',
    'invalidOpeningBalance': 'ትክክለኛ መነሻ ቀሪ ሂሳብ ያስገቡ።',
    'invalidAmount': 'ትክክለኛ መጠን ያስገቡ።',
    'showBalances': 'ቀሪ ሂሳቦችን አሳይ',
    'balanceHiddenSpoken': 'ቀሪ ሂሳብ ተደብቋል',
    'chooseTwoAccounts': 'ሁለት የተለያዩ ሂሳቦችን ይምረጡ።',
    'toAccount': 'ወደ ሂሳብ',
    'fromAccount': 'ከሂሳብ',
    'adjustment': 'የቀሪ ሂሳብ ማስተካከያ',
    'transactionConfirmed': 'ግብይቱ ተረጋግጧል',
    'alreadyRecorded': 'ይህ ግብይት ከዚህ በፊት ተመዝግቧል',
    'smsBalanceDiffers': 'ተረጋግጧል። ባንኩ የዚህን ሂሳብ ቀሪ {balance} ነው ይላል።',
    'matchBalance': 'አስተካክል',
    'olderThanTracking':
        'ይህ መልዕክት ሂሳቡ ከመጨመሩ ወይም ክትትሉ ከመብራቱ በፊት የደረሰ ነው። ካረጋገጡት የሂሳቡ ቀሪ ይቀየራል።',
    'confirmAll': 'ሁሉንም አረጋግጥ',
    'confirmAllTitle': 'እነዚህን መልዕክቶች ያረጋግጡ?',
    'confirmAllBody':
        '{count} ከፍተኛ እርግጠኝነት ያላቸውን መልዕክቶች እያንዳንዳቸውን ወደ ባንካቸው ሂሳብ ያክሉ።',
    'confirmAllDone': '{count} ግብይቶች ተረጋግጠዋል።',
    'confirmAllSkipped': '{count} ተዘልለዋል፤ መጀመሪያ ለዚያ ባንክ ሂሳብ ያክሉ።',
    'manageAccounts': 'ሂሳቦችዎን ያስተዳድሩ',
    'correctBalance': 'ቀሪ ሂሳብ አስተካክል',
    'currentBalance': 'የአሁኑ ቀሪ ሂሳብ',
    'correctBalanceHint':
        'ባንክዎ ወይም ዋሌትዎ አሁን የሚያሳየውን ቀሪ ሂሳብ ያስገቡ። ልዩነቱ እንደ ማስተካከያ ይቀመጣል፤ እንደ ገቢ ወይም ወጪ አይቆጠርም።',
    'balanceMatches': 'ቀሪ ሂሳቡ ቀድሞውኑ ትክክል ነው።',
    'balanceCorrected': 'ቀሪ ሂሳቡ ተስተካክሏል',
    'archive': 'ወደ ማህደር',
    'unarchive': 'መልስ',
    'archived': 'በማህደር ያለ',
    'monthlySnapshot': 'የወር አጠቃላይ እይታ',
    'scoreHowMade': 'ውጤቱ እንዴት ይሰላል',
    'scoreNeedsAttention': 'ትኩረት ያስፈልገዋል',
    'scoreFair': 'መካከለኛ',
    'scoreGood': 'ጥሩ',
    'scoreExcellent': 'በጣም ጥሩ',
    'factorSavings': 'የዚህ ወር የቁጠባ መጠን',
    'factorBills': 'በወቅቱ የተከፈሉ ክፍያዎች',
    'factorEmergency': 'የአደጋ ጊዜ ቁጠባ',
    'factorStability': 'የወጪ መረጋጋት',
    'scoreNotEnoughHint':
        'ውጤት ለማየት በዚህ ወር ገቢዎን ጨምሮ ቢያንስ 3 ግብይቶችን ይመዝግቡ።',
    'scoreWeakest': 'በይበልጥ ሊሻሻል የሚችለው፦ {factor}።',
    'scoreAllStrong': 'በዚህ ወር ሁሉም የውጤትዎ ክፍሎች ጠንካራ ናቸው።',
    'recTopCategory':
        '{category} የዚህ ወር ወጪዎ {percent}% ነው። እዚያ ትንሽ መቀነስ ትልቅ ለውጥ ያመጣል።',
    'recBillsSoon': 'በሚቀጥሉት 3 ቀናት የሚደርሱ ክፍያዎች፦ {count}።',
    'recLowSavings':
        'በዚህ ወር ከገቢዎ {percent}% አስቀርተዋል። ቢያንስ 10% ለማስቀረት ይሞክሩ።',
    'recOldPending': 'አንዳንድ የባንክ መልዕክቶች ከ3 ቀናት በላይ ክለሳ እየጠበቁ ነው።',
    'recAllGood': 'በዚህ ወር ትኩረት የሚፈልግ ነገር የለም። በዚሁ ይቀጥሉ።',
    'reviewBills': 'ክፍያዎችን ይመልከቱ',
    'businessEntry':
        'የንግድ (የሱቅ) ገንዘብ',
    'testCash':
        'ጥሬ ገንዘብ',
    'testGoal':
        'ግብ',
    'budget':
        'በጀት',
    'loans':
        'ብድሮች',
    'monthlyTarget':
        'የወሩ አጠቃላይ ግብ',
    'edit':
        'አስተካክል',
    'targetIncome':
        'የታለመ ወርሃዊ ገቢ',
    'plannedSpending':
        'የታቀደ ወርሃዊ ወጪ ገደብ',
    'categoryBudgets':
        'የምድብ በጀት ወሰኖች',
    'noBudgets':
        'እስካሁን በጀት የለም። ለአንድ ምድብ ወርሃዊ ገደብ ያክሉና እዚህ ይከታተሉ።',
    'setBudget':
        'በጀት ወስን',
    'monthlyLimit':
        'የወሩ ገደብ',
    'remove':
        'አስወግድ',
    'loansHint':
        'ለሰው ያበደሩትንና ከሰው የተበደሩትን ገንዘብ ይከታተሉ።',
    'addLoan':
        'ብድር መዝግብ',
    'owedToYou':
        'ሊከፈልዎ የሚገባ',
    'youOwe':
        'የሚከፍሉት',
    'settled':
        'ተከፍሎ አልቋል',
    'lent':
        'ያበደሩት',
    'borrowed':
        'የተበደሩት',
    'left':
        'ቀርቷል',
    'recordPayment':
        'ክፍያ መዝግብ',
    'markSettled':
        'እንደተከፈለ ምልክት አድርግ',
    'delete':
        'ሰርዝ',
    'amountLabel':
        'የገንዘብ መጠን',
    'personName':
        'የሰውየው ስም',
    'loanInvalid':
        'ስምና የገንዘብ መጠን ያስገቡ።',
    'csvSub':
        'የግብይት ዝርዝሩን እንደ ፋይል ያስቀምጡ',
    'backup':
        'የመረጃ ቅጂ',
    'backupSub':
        'ቅጂ ያስቀምጡ ወይም ይመልሱ',
    'merchantMode':
        'የነጋዴ / ሱቅ ሁነታ',
    'merchantModeSub':
        'የንግድ ገቢና ወጪዎችን ከግል ኑሮ ወጪዎች ይለያል።',
    'saveBackup':
        'የመረጃ ቅጂ ፋይል አስቀምጥ',
    'restoreBackup':
        'የቀድሞ መረጃን መልስ',
    'backupWarning':
        'የመረጃ ቅጂ ፋይሎች አልተመሰጠሩም። በሚስጥር ቦታ ያስቀምጧቸው።',
    'restoreConfirm':
        'በብርዋይዝ ያለው መረጃ በሙሉ በቅጂው ይተካል። ቅንብሮችዎና ፒንዎ እንዳሉ ይቆያሉ።',
    'restoreDone':
        'መረጃዎች በተሳካ ሁኔታ ተመልሰዋል።',
    'restoreInvalid':
        'ፋይሉ ትክክለኛ የብርዋይዝ ቅጂ አይደለም። ምንም አልተቀየረም።',
    'fileFailed':
        'ፋይሉን መጠቀም አልተቻለም። እንደገና ይሞክሩ።',
    'fileSaved':
        'ፋይሉ ተቀምጧል።',
    'monitoredBanks':
        'ክትትል የሚደረግባቸው ባንኮች እና ዋሌቶች',
    'monitoredBanksCount':
        '{count} ተመርጠዋል',
    'security':
        'ደህንነት',
    'pinLock':
        'የፒን ኮድ (PIN) መቆለፊያ',
    'pinOn':
        'በርቷል። ወደ ብርዋይዝ ሲመለሱ ፒን ይጠይቃል።',
    'pinOff':
        'ጠፍቷል',
    'privacyPolicy':
        'የግላዊነት ፖሊሲ',
    'eraseAll':
        'ሁሉንም መረጃዎች ሰርዝ',
    'pinEnter':
        'የ4-አሃዝ ፒን ኮድዎን ያስገቡ',
    'pinForgetWarning':
        'ከረሱት በAndroid ቅንብሮች ውስጥ የብርዋይዝን ማከማቻ ማጽዳት ይኖርብዎታል፤ ይህም ሁሉንም መረጃ ያጠፋል።',
    'pinRemoveConfirm':
        'የፒን መቆለፊያውን ላጥፋ?',
    'turnOff':
        'አጥፋ',
    'eraseConfirm':
        'ይህ በዚህ ስልክ ያሉትን ሂሳቦች፣ ግብይቶች፣ እቅዶችና ቅንብሮች በሙሉ ያጠፋል፤ የSMS ክትትልንም ያጠፋል። ሊመለስ አይችልም። ካስፈለገዎ መጀመሪያ የመረጃ ቅጂ ያስቀምጡ።',
    'eraseEverything':
        'ሁሉንም አጥፋ',
    'erased':
        'መረጃዎች በሙሉ ጠፍተዋል።',
    'privacyPolicyBody':
        '1. ሁሉም መረጃ በዚህ ስልክ ላይ ብቻ ይቀመጣል። ብርዋይዝ መለያ፣ ሰርቨር ወይም የአጠቃቀም ክትትል የለውም፤ ምንም ነገር ወደ ውጭ አይልክም።\n\n2. የSMS ፈቃድ የሚውለው በቅንብሮች ውስጥ ከመረጧቸው ባንኮችና ዋሌቶች የሚመጡ መልዕክቶችን ግብይት ለመለየት ብቻ ነው። የግል መልዕክቶች አይነበቡም፣ አይቀመጡም።\n\n3. ግልጽ መልዕክቶች በራሳቸው ወደ ሂሳቦችዎ ይመዘገባሉ፤ ግልጽ ያልሆኑት በSMS መልዕክቶች ውስጥ እርስዎን ይጠብቃሉ። በቅንብሮች ውስጥ ክትትሉን ሲያጠፉ ወዲያውኑ ይቆማል።\n\n4. የመረጃ ቅጂዎችና የCSV ፋይሎች እርስዎ በመረጡት ቦታ ብቻ ይቀመጣሉ። አልተመሰጠሩም፤ ስለዚህ ፋይሎቹን በሚስጥር ይያዙ።\n\n5. የAndroid ምትኬ ለብርዋይዝ መረጃ ጠፍቷል። በቅንብሮች ውስጥ «ሁሉንም መረጃዎች ሰርዝ» ሁሉንም ያጠፋል።\n\n6. Google Play የSMS ፈቃዶችን ይገድባል፤ ይህ ስሪት በቀጥታ ለመጫን የተዘጋጀ ነው።',
    'understood':
        'ተረድቻለሁ',
    'pinWrong':
        'የተሳሳተ ፒን ኮድ። እንደገና ይሞክሩ።',
    'welcomeTitle':
        'እንኳን ወደ ብርዋይዝ በደህና መጡ',
    'welcomeSubtitle':
        'የእርስዎን የገንዘብ እንቅስቃሴ ያለ ኢንተርኔት በከፍተኛ ሚስጥራዊነት የሚከታተል መተግበሪያ።',
    'chooseLanguage':
        'ቋንቋ ይምረጡ',
    'privacyFirstHeading':
        'ሙሉ በሙሉ በስልክዎ ላይ ብቻ የሚቀመጥ',
    'privacyFirstBody':
        'የባንክ እና የቴሌብር መልዕክቶችዎ ከስልክዎ ውጪ ወደ የትኛውም ሰርቨር አይላኩም። ሁሉም ስሌት በስልክዎ ውስጥ ብቻ ይከናወናል።',
    'cashFlowTrend':
        'የገንዘብ ፍሰት (ያለፉት 4 ወራት)',
    'editAmount':
        'መጠኑን ቀይር',
    'pinAgain':
        'እንደገና ያስገቡ',
    'pinMismatch':
        'ሁለቱ ፒኖች አይመሳሰሉም።',
    'shopTag':
        'ሱቅ',
    'banksTitle':
        'የእርስዎ የትኞቹ ባንኮችና ዋሌቶች ናቸው?',
    'banksBody':
        'ብርዋይዝ መልዕክቶችን የሚያነበው ከመረጧቸው ብቻ ነው። ከሌሎቹ የሚመጡ መልዕክቶች ይተዋሉ፤ ከእነሱ ቀድሞ የተመዘገበውም ይወገዳል። በኋላ በቅንብሮች ውስጥ መቀየር ይችላሉ።',
    'alertsFound':
        'የተገኙ መልዕክቶች: {count}',
    'done':
        'ጨርሻለሁ',
  },
};

String t(String language, String key) =>
    _strings[language]?[key] ?? _strings['en']![key] ?? key;

/// [t] with `{name}` placeholders filled in.
String tf(String language, String key, Map<String, Object> values) {
  var text = t(language, key);
  values.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
  return text;
}
