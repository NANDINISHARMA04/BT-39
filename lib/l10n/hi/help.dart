// Hindi strings for this part of the app. Keys are the exact English text.
// The help assistant: "where is / how do I" answers, help topics and voice.
const hiHelp = <String, String>{
  // Assistant screen
  'Ask anything, or where to find something': 'कुछ भी पूछें, या कोई चीज़ कहाँ है',
  'Read answers aloud': 'जवाब बोलकर सुनाएँ',
  'Answers will be read aloud': 'जवाब बोलकर सुनाए जाएँगे',
  'Read aloud is off': 'बोलकर सुनाना बंद है',
  'Listening… speak now': 'सुन रहा हूँ… अब बोलें',
  'Listening…': 'सुन रहा हूँ…',
  'Stop listening': 'सुनना बंद करें',
  'Speak your question': 'अपना सवाल बोलें',
  'Help topics': 'मदद के विषय',
  'Tap a topic. I\'ll show you where it is, step by step.': 'किसी विषय पर टैप करें। मैं एक-एक कदम में बताऊँगा कि वह कहाँ है।',
  'Find something': 'कुछ ढूँढें',
  'Get help': 'मदद लें',
  'Make it easier': 'आसान बनाएँ',
  'Call {name}': '{name} को कॉल करें',
  'This device can\'t place calls from the app. Dial {phone} from your phone.': 'यह डिवाइस ऐप से कॉल नहीं कर सकता। अपने फ़ोन से {phone} डायल करें।',

  // Help topic buttons (shown with tr() from a list)
  'Reports': 'रिपोर्ट',
  'Medicines': 'दवाएँ',
  'Appointments': 'अपॉइंटमेंट',
  'Family': 'परिवार',
  'Insurance': 'बीमा',
  'SOS · call 112': 'SOS · 112 पर कॉल',
  'Call family': 'परिवार को कॉल',
  'I feel unwell': 'तबीयत ठीक नहीं',
  'Language': 'भाषा',
  'Bigger text': 'बड़े अक्षर',
  'What can you do?': 'आप क्या कर सकते हैं?',
  // Questions the buttons ask (the Hindi versions route to the same answers)
  'Where are my reports?': 'मेरी रिपोर्ट कहाँ हैं?',
  'Where are my medicines?': 'मेरी दवाइयाँ कहाँ देखूँ?',
  'How do I book an appointment?': 'अपॉइंटमेंट कैसे बुक करूँ?',
  'Where are my family contacts?': 'मेरे परिवार के संपर्क कहाँ हैं?',
  'Where is my insurance?': 'मेरा बीमा कहाँ है?',
  'Call my family': 'मेरे परिवार को फ़ोन करें',
  'How do I change the language?': 'भाषा कैसे बदलूँ?',
  'How do I make the text bigger?': 'अक्षर बड़े कैसे करूँ?',
  'What can you help with?': 'आप किन चीज़ों में मदद कर सकते हैं?',
  'Where is the SOS button?': 'SOS बटन कहाँ है?',

  // Replies: common steps
  'Tap Me at the bottom of the screen.': 'स्क्रीन के नीचे "मैं" पर टैप करें।',
  'Tap Alerts at the bottom of the screen.': 'स्क्रीन के नीचे "अलर्ट" पर टैप करें।',
  'Tap Care at the bottom of the screen.': 'स्क्रीन के नीचे "देखभाल" पर टैप करें।',
  'Tap Insights at the bottom of the screen.': 'स्क्रीन के नीचे "जानकारी" पर टैप करें।',
  'Open Me': '"मैं" खोलें',
  'Open Care': 'देखभाल खोलें',
  'Open Insights': 'जानकारी खोलें',
  'Open alerts': 'अलर्ट खोलें',

  // Records
  'Your reports and medical records are kept in Me → Medical records.': 'आपकी रिपोर्ट और मेडिकल रिकॉर्ड मैं → मेडिकल रिकॉर्ड में रखे हैं।',
  'Tap Medical records.': '"मेडिकल रिकॉर्ड" पर टैप करें।',
  'To add a report, tap + at the top and choose a photo or PDF.': 'नई रिपोर्ट जोड़ने के लिए ऊपर + पर टैप करें और फ़ोटो या PDF चुनें।',
  'Open medical records': 'मेडिकल रिकॉर्ड खोलें',

  // Medicines and conditions
  'Your medicines, conditions and allergies are in Me → Health profile.': 'आपकी दवाएँ, बीमारियाँ और एलर्जी मैं → हेल्थ प्रोफ़ाइल में हैं।',
  'Tap Health profile.': '"हेल्थ प्रोफ़ाइल" पर टैप करें।',
  'Add or change a medicine, then tap Save.': 'दवा जोड़ें या बदलें, फिर "सेव करें" पर टैप करें।',
  'You have {n} medicine saved.': 'आपकी {n} दवा सेव है।',
  'You have {n} medicines saved.': 'आपकी {n} दवाएँ सेव हैं।',
  'Open health profile': 'हेल्थ प्रोफ़ाइल खोलें',

  // Insurance
  'Your insurance policies and claims are in Me → Insurance & claims.': 'आपकी बीमा पॉलिसी और क्लेम मैं → बीमा और क्लेम में हैं।',
  'Tap Insurance & claims.': '"बीमा और क्लेम" पर टैप करें।',
  'Tap a claim to see its status, or tap + to add a policy or claim.': 'क्लेम की स्थिति देखने के लिए उस पर टैप करें, या पॉलिसी या क्लेम जोड़ने के लिए + पर टैप करें।',

  // Family
  'Your family, emergency contacts and caregiver are in Me → Family.': 'आपका परिवार, इमरजेंसी संपर्क और देखभाल करने वाले मैं → परिवार में हैं।',
  'Tap Family.': '"परिवार" पर टैप करें।',
  'Tap a person to call them, or to make them your caregiver or emergency contact.': 'किसी व्यक्ति पर टैप करें, उन्हें कॉल करने के लिए या उन्हें देखभाल करने वाला या इमरजेंसी संपर्क बनाने के लिए।',
  'Open family': 'परिवार खोलें',
  'No family member with a phone number is saved yet. Add one in Me → Family.': 'अभी किसी परिवार वाले का फ़ोन नंबर सेव नहीं है। मैं → परिवार में जोड़ें।',
  '{name} ({relation}) can be called on {phone}.': '{name} ({relation}) को {phone} पर कॉल कर सकते हैं।',
  'Tap the button below to call. In an emergency, call 112 first.': 'कॉल करने के लिए नीचे का बटन दबाएँ। इमरजेंसी में पहले 112 पर कॉल करें।',

  // Medical ID
  'Your Medical ID shows your blood group, allergies, medicines and emergency contacts to anyone helping you.': 'आपकी मेडिकल ID मदद करने वाले को आपका ब्लड ग्रुप, एलर्जी, दवाएँ और इमरजेंसी संपर्क दिखाती है।',
  'Under Emergency, tap Medical ID.': '"इमरजेंसी" में "मेडिकल ID" पर टैप करें।',
  'Your blood group: {bg}.': 'आपका ब्लड ग्रुप: {bg}।',
  'Open Medical ID': 'मेडिकल ID खोलें',

  // SOS
  'The red SOS button is on the Today screen. You can also find it in Me → Emergency SOS.': 'लाल SOS बटन "आज" स्क्रीन पर है। यह मैं → इमरजेंसी SOS में भी मिलता है।',
  'Tap SOS.': 'SOS पर टैप करें।',
  'Press and hold the big button for 3 seconds.': 'बड़े बटन को 3 सेकंड तक दबाकर रखें।',
  'It calls 112 and alerts {names}.': 'यह 112 पर कॉल करता है और {names} को अलर्ट भेजता है।',

  // Feeling unwell
  'I\'m sorry you\'re not feeling well.': 'मुझे दुख है कि आपकी तबीयत ठीक नहीं है।',
  'If you have chest pain, trouble breathing, or feel faint, call 112 or press SOS now.': 'अगर सीने में दर्द है, साँस लेने में दिक्कत है या चक्कर आ रहे हैं, तो अभी 112 पर कॉल करें या SOS दबाएँ।',
  'Otherwise, sit down, rest, and drink some water.': 'नहीं तो बैठ जाएँ, आराम करें और थोड़ा पानी पिएँ।',
  'You can talk to a doctor by video.': 'आप वीडियो पर डॉक्टर से बात कर सकते हैं।',
  'Your band right now:': 'अभी आपका बैंड:',
  'Talk to a doctor': 'डॉक्टर से बात करें',

  // Held-back alerts and alerts
  'Alerts that AdaptAlert held back (it didn\'t buzz you) are kept in Alerts → Held back.': 'जो अलर्ट AdaptAlert ने रोके (आपको नहीं बजाए), वे अलर्ट → रोके गए में रखे हैं।',
  'Tap Held back at the top.': 'ऊपर "रोके गए" पर टैप करें।',
  'Safety limits always alert, even for patterns that are usually held back.': 'सुरक्षा सीमा पर अलर्ट हमेशा आता है, उन पैटर्न पर भी जो आम तौर पर रोके जाते हैं।',
  'Your alerts are in the Alerts tab.': 'आपके अलर्ट "अलर्ट" टैब में हैं।',
  'Alerts waiting for you are under Needs reply. Tap how you feel. Your answer helps AdaptAlert learn.': 'जिन अलर्ट का जवाब देना है, वे "जवाब बाक़ी" में हैं। बताएँ कि आप कैसा महसूस कर रहे हैं। आपके जवाब से AdaptAlert सीखता है।',
  'To see why an alert was sent, tap See how AdaptAlert decided.': 'अलर्ट क्यों भेजा गया, यह जानने के लिए "देखें AdaptAlert ने कैसे तय किया" पर टैप करें।',
  'To see this for any alert: open Alerts, tap the alert, then tap "See how AdaptAlert decided".': 'किसी भी अलर्ट के लिए यह देखने को: अलर्ट खोलें, अलर्ट पर टैप करें, फिर "देखें AdaptAlert ने कैसे तय किया" पर टैप करें।',

  // Appointments and doctors
  'Appointments are in the Care tab.': 'अपॉइंटमेंट "देखभाल" टैब में हैं।',
  'To book: tap the search bar, pick a doctor, then pick a time.': 'बुक करने के लिए: सर्च बार पर टैप करें, डॉक्टर चुनें, फिर समय चुनें।',
  'To change one: find your appointment, then tap Reschedule or Cancel.': 'बदलने के लिए: अपना अपॉइंटमेंट ढूँढें, फिर "समय बदलें" या "रद्द करें" पर टैप करें।',
  'You can find a doctor in the Care tab.': 'डॉक्टर आपको "देखभाल" टैब में मिलेंगे।',
  'Tap the search bar, or a speciality like Heart.': 'सर्च बार पर, या "हृदय" जैसी किसी विशेषज्ञता पर टैप करें।',
  'Tap a doctor to see fees and times, then tap Book appointment.': 'फ़ीस और समय देखने के लिए डॉक्टर पर टैप करें, फिर "अपॉइंटमेंट बुक करें" पर टैप करें।',
  'To talk to a doctor, book a video visit.': 'डॉक्टर से बात करने के लिए वीडियो अपॉइंटमेंट बुक करें।',
  'Tap the button below to find a doctor.': 'डॉक्टर खोजने के लिए नीचे का बटन दबाएँ।',
  'Pick a doctor who offers Video, then pick a time.': 'ऐसा डॉक्टर चुनें जो वीडियो पर देखते हों, फिर समय चुनें।',
  'At the time of the visit, open Care and tap Join call.': 'अपॉइंटमेंट के समय "देखभाल" खोलें और "कॉल जॉइन करें" पर टैप करें।',
  'If it is urgent, call 112 or press SOS.': 'अगर ज़रूरी हो, तो 112 पर कॉल करें या SOS दबाएँ।',

  // Research Lab, how it works, trends
  'The Research Lab runs a 30-day study on simulated patients and compares AdaptAlert with other alarm systems.': 'रिसर्च लैब नकली (सिमुलेटेड) मरीज़ों पर 30 दिन की स्टडी चलाती है और AdaptAlert की तुलना दूसरे अलार्म सिस्टम से करती है।',
  'Scroll down and tap Open the Research Lab.': 'नीचे स्क्रॉल करें और "रिसर्च लैब खोलें" पर टैप करें।',
  'AdaptAlert learns your own normal heart rate, oxygen and temperature. It alerts when something is unusual for you, not just for everyone.': 'AdaptAlert आपकी अपनी सामान्य धड़कन, ऑक्सीजन और तापमान सीखता है। यह तब अलर्ट भेजता है जब कुछ आपके लिए असामान्य हो, न कि सिर्फ़ सबके लिए।',
  'When you or your doctor answer an alert, it learns which patterns are harmless, so you get fewer false alarms. Safety limits always alert.': 'जब आप या आपके डॉक्टर किसी अलर्ट का जवाब देते हैं, तो यह सीखता है कि कौन-से पैटर्न नुकसानदेह नहीं हैं, ताकि झूठे अलर्ट कम आएँ। सुरक्षा सीमा पर अलर्ट हमेशा आता है।',
  'Your charts and trends are in the Insights tab.': 'आपके चार्ट और ट्रेंड "जानकारी" टैब में हैं।',
  'Choose Heart rate, Oxygen or Temperature at the top.': 'ऊपर धड़कन, ऑक्सीजन या तापमान चुनें।',

  // Settings
  'You can switch between English and Hindi at any time.': 'आप कभी भी English और हिन्दी के बीच बदल सकते हैं।',
  'Under Preferences, find Language and choose English or हिन्दी.': '"पसंद" में "भाषा" ढूँढें और English या हिन्दी चुनें।',
  'Or tap the button below to switch now.': 'या अभी बदलने के लिए नीचे का बटन दबाएँ।',
  'Switch to English': 'English में बदलें',
  'Switch to हिन्दी': 'हिन्दी में बदलें',
  'You can choose a light or dark screen.': 'आप हल्की (लाइट) या गहरी (डार्क) स्क्रीन चुन सकते हैं।',
  'Under Preferences, find Appearance.': '"पसंद" में "दिखावट" ढूँढें।',
  'Choose Light, Dark, or Auto (follows your phone).': 'लाइट, डार्क या ऑटो (फ़ोन के हिसाब से) चुनें।',
  'You can turn alert notifications on or off.': 'आप अलर्ट के नोटिफ़िकेशन चालू या बंद कर सकते हैं।',
  'Under Alerts, turn Notifications on or off.': '"अलर्ट" में "नोटिफ़िकेशन" चालू या बंद करें।',
  'You can make the text bigger, use an easier home screen, and have alerts read aloud.': 'आप अक्षर बड़े कर सकते हैं, आसान होम स्क्रीन चुन सकते हैं, और अलर्ट बोलकर सुन सकते हैं।',
  'Tap the button below, or open Me → Accessibility.': 'नीचे का बटन दबाएँ, या मैं → सुगमता खोलें।',
  'Choose a text size and turn on the options you like.': 'अक्षरों का आकार चुनें और जो विकल्प पसंद हों, उन्हें चालू करें।',
  'In this chat, tap the speaker at the top to hear answers read aloud.': 'इस चैट में जवाब सुनने के लिए ऊपर स्पीकर पर टैप करें।',
  'Open text size & easy mode': 'अक्षर का आकार और आसान मोड खोलें',
  'The simulator plays a pretend situation on the band, like a fast heart rate or low oxygen, so you can see how alerts work. It is for demos only.': 'सिम्युलेटर बैंड पर एक नकली स्थिति चलाता है, जैसे तेज़ धड़कन या कम ऑक्सीजन, ताकि आप देख सकें कि अलर्ट कैसे काम करते हैं। यह सिर्फ़ डेमो के लिए है।',
  'Tap the button below (or Me → Band simulator).': 'नीचे का बटन दबाएँ (या मैं → बैंड सिम्युलेटर)।',
  'Pick a scenario and watch the Today screen.': 'कोई स्थिति चुनें और "आज" स्क्रीन देखें।',
  'To sign out:': 'साइन आउट करने के लिए:',
  'Scroll to the bottom and tap Sign out (or Leave Demo Mode).': 'सबसे नीचे स्क्रॉल करें और "साइन आउट" (या "डेमो मोड छोड़ें") पर टैप करें।',

  // Alert levels, normal ranges, SpO₂, the band
  'Alerts have 4 levels:': 'अलर्ट के 4 लेवल हैं:',
  'Check-in (teal): something small changed. Answer when you can.': 'हालचाल (हरा-नीला): कुछ छोटा बदला है। जब हो सके, जवाब दें।',
  'Warning (orange): keep an eye on it and rest. Your caregiver is told.': 'चेतावनी (नारंगी): ध्यान रखें और आराम करें। आपकी देखभाल करने वाले को बताया जाता है।',
  'Urgent (red): needs attention soon. Your doctor is told.': 'ज़रूरी (लाल): जल्दी ध्यान देना है। आपके डॉक्टर को बताया जाता है।',
  'Critical (red): a safety limit was reached. Get help now. Your emergency contacts are alerted.': 'गंभीर (लाल): सुरक्षा सीमा पार हुई है। अभी मदद लें। आपके इमरजेंसी संपर्कों को अलर्ट जाता है।',
  'Green on the Today screen means everything is normal for you.': '"आज" स्क्रीन पर हरा रंग मतलब सब कुछ आपके लिए सामान्य है।',
  'SpO₂ means how much oxygen your blood is carrying. It is shown as a percentage.': 'SpO₂ का मतलब है कि आपके खून में कितनी ऑक्सीजन है। यह प्रतिशत (%) में दिखता है।',
  'Healthy is 95% to 100%. If it stays at or below 91% for 2 minutes, AdaptAlert always alerts.': '95% से 100% ठीक है। अगर यह 2 मिनट तक 91% या उससे कम रहे, तो AdaptAlert हमेशा अलर्ट भेजता है।',
  'Yours right now: {spo2}%.': 'अभी आपका: {spo2}%।',
  'Normal ranges for most adults at rest:': 'आराम के समय ज़्यादातर बड़ों की सामान्य सीमा:',
  'Heart rate: 60 to 100 beats a minute.': 'धड़कन: एक मिनट में 60 से 100।',
  'Oxygen (SpO₂): 95% to 100%. Below 92% needs a doctor.': 'ऑक्सीजन (SpO₂): 95% से 100%। 92% से कम हो तो डॉक्टर को दिखाएँ।',
  'Temperature: 36.1 to 37.2 °C. 38 °C or more is a fever.': 'तापमान: 36.1 से 37.2 °C। 38 °C या ज़्यादा बुखार है।',
  'AdaptAlert also learns your own normal, which may be a little different.': 'AdaptAlert आपकी अपनी सामान्य सीमा भी सीखता है, जो थोड़ी अलग हो सकती है।',
  'Right now: heart rate {hr} bpm, oxygen {spo2}%, temperature {temp} °C.': 'अभी: धड़कन {hr} bpm, ऑक्सीजन {spo2}%, तापमान {temp} °C।',
  'Your wrist band reads your heart rate, oxygen and temperature every minute and sends them to the app. If the readings look wrong:': 'आपका कलाई बैंड हर मिनट आपकी धड़कन, ऑक्सीजन और तापमान पढ़कर ऐप को भेजता है। अगर रीडिंग गलत लगे:',
  'Wear the band snug, one finger above the wrist bone.': 'बैंड को कसकर, कलाई की हड्डी से एक उंगली ऊपर पहनें।',
  'Keep your hand still for a minute.': 'एक मिनट तक हाथ स्थिर रखें।',
  'Wipe the sensor on the back with a dry cloth.': 'पीछे वाले सेंसर को सूखे कपड़े से पोंछें।',
  'Right now your band is reading well.': 'अभी आपका बैंड ठीक से पढ़ रहा है।',
  'Right now the band signal is weak, so readings are being ignored.': 'अभी बैंड का सिग्नल कमज़ोर है, इसलिए रीडिंग छोड़ी जा रही हैं।',

  // When the question isn't understood
  'Sorry, I didn\'t understand that.': 'माफ़ कीजिए, मैं यह समझ नहीं पाया।',
  'I can tell you where things are in the app, explain your health readings and alerts, and help in an emergency.': 'मैं बता सकता हूँ कि ऐप में कौन-सी चीज़ कहाँ है, आपकी रीडिंग और अलर्ट समझा सकता हूँ, और इमरजेंसी में मदद कर सकता हूँ।',
  'Tap a question below, or ask in your own words, like "Where are my reports?"': 'नीचे किसी सवाल पर टैप करें, या अपने शब्दों में पूछें, जैसे "मेरी रिपोर्ट कहाँ हैं?"',
};
