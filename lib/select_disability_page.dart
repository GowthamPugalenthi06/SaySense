import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'setup_profile_page.dart'; // Import your separate profile page

void main() {
  runApp(MaterialApp(
    home: SelectDisabilityPage(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'SF Pro Display',
    ),
  ));
}

class SelectDisabilityPage extends StatefulWidget {
  @override
  _SelectDisabilityPageState createState() => _SelectDisabilityPageState();
}

class _SelectDisabilityPageState extends State<SelectDisabilityPage>
    with TickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAvailable = false;
  String _spokenText = '';
  String _selectedOption = '';
  bool _waitingForConfirmation = false;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
    _speakOptions();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          setState(() => _isListening = false);
          _pulseController.stop();
        }
      },
      onError: (error) {
        print('Speech Error: $error');
      },
    );
    setState(() {});
  }

  Future<void> _speakOptions() async {
    await _flutterTts.awaitSpeakCompletion(true);
    _flutterTts.setCompletionHandler(() {
      _startListening();
    });

    await _flutterTts.speak(
      "Please select your disability. "
      "Option 1: Vision Disability. "
      "Option 2: Hearing Disability. "
      "Option 3: Speech Disability. "
      "Option 4: Physical Disability. "
      "Option 5: Cognitive Disability. "
      "Say Vision, Hearing, Speech, Physical, or Cognitive to select.",
    );
  }

  void _startListening() async {
    if (_isAvailable && !_isListening) {
      setState(() => _isListening = true);
      _pulseController.repeat(reverse: true);
      bool hasResult = false;

      await _speech.listen(
        onResult: (val) {
          setState(() {
            _spokenText = val.recognizedWords;
          });
          hasResult = val.recognizedWords.trim().isNotEmpty;
          _handleSpeech(_spokenText);
        },
        listenFor: Duration(seconds: 6),
      );

      _speech.statusListener = (status) async {
        if (status == 'done') {
          setState(() => _isListening = false);
          _pulseController.stop();
          if (!hasResult && !_waitingForConfirmation) {
            await _flutterTts.speak("Please select the option.");
          }
        }
      };
    }
  }

  void _handleSpeech(String text) async {
    final lowerText = text.toLowerCase();

    if (_waitingForConfirmation && lowerText.contains("confirm")) {
      _confirmOption();
    } else if (lowerText.contains("vision")) {
      _selectOption("Vision Disability");
    } else if (lowerText.contains("hearing")) {
      _selectOption("Hearing Disability");
    } else if (lowerText.contains("speech")) {
      _selectOption("Speech Disability");
    } else if (lowerText.contains("physical")) {
      _selectOption("Physical Disability");
    } else if (lowerText.contains("cognitive")) {
      _selectOption("Cognitive Disability");
    } else if (lowerText.contains("hello")) {
      await _flutterTts.speak("Mic activated. Please speak now.");
      _flutterTts.setCompletionHandler(() {
        _startListening();
      });
    } else {
      if (!_waitingForConfirmation) {
        if (_isListening) {
          _speech.stop();
          setState(() => _isListening = false);
          _pulseController.stop();
        }

        if (text.trim().isEmpty) {
          await _flutterTts.speak("Please select the option.");
        } else {
          await _flutterTts.speak("Sorry, I didn't understand. Please select an option.");
        }
      }
    }
  }

  Future<void> _selectOption(String optionName) async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _selectedOption = optionName;
      _waitingForConfirmation = true;
    });
    _pulseController.stop();

    await _flutterTts.speak(
      "You selected $optionName. Say Confirm or tap Confirm to confirm your choice."
    );

    await Future.delayed(Duration(milliseconds: 500));
    _startListening();
  }

  Future<void> _confirmOption() async {
    await _speech.stop();
    setState(() {
      _isListening = false;
      _waitingForConfirmation = false;
    });
    _pulseController.stop();

    await _flutterTts.speak(
      "Thank you. Your choice $_selectedOption has been confirmed. Now proceeding to setup your profile."
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => SetupProfilePage(selectedDisability: _selectedOption),
      ),
    );
  }

  Widget _buildDisabilityOption({
    required String title,
    required String emoji,
    required VoidCallback onTap,
    required Color color,
  }) {
    bool isSelected = _selectedOption == title;
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isSelected 
            ? [color.withOpacity(0.8), color]
            : [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
            blurRadius: isSelected ? 15 : 8,
            offset: Offset(0, isSelected ? 8 : 4),
          ),
        ],
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade200,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withOpacity(0.9) : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.grey.shade800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Tap to select this option",
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Select Disability",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade600,
        elevation: 0,
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade600, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.accessibility_new,
                      size: 48,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Select Your Disability Type',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Choose the option that best describes your needs. You can use voice commands or tap to select.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 32),
              
              // Voice Status Indicator
              if (_isListening)
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        margin: EdgeInsets.only(bottom: 20),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.red.shade300, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic, color: Colors.red.shade600, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Listening... Please speak now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              
              // Disability Options
              _buildDisabilityOption(
                title: "Vision Disability",
                emoji: "👁️",
                onTap: () => _selectOption("Vision Disability"),
                color: Colors.purple,
              ),
              _buildDisabilityOption(
                title: "Hearing Disability",
                emoji: "👂",
                onTap: () => _selectOption("Hearing Disability"),
                color: Colors.orange,
              ),
              _buildDisabilityOption(
                title: "Speech Disability",
                emoji: "🗣️",
                onTap: () => _selectOption("Speech Disability"),
                color: Colors.green,
              ),
              _buildDisabilityOption(
                title: "Physical Disability",
                emoji: "♿",
                onTap: () => _selectOption("Physical Disability"),
                color: Colors.blue,
              ),
              _buildDisabilityOption(
                title: "Cognitive Disability",
                emoji: "🧠",
                onTap: () => _selectOption("Cognitive Disability"),
                color: Colors.teal,
              ),
              
              // Confirmation Button
              if (_waitingForConfirmation) ...[
                SizedBox(height: 20),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  child: ElevatedButton(
                    onPressed: _confirmOption,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 24),
                        SizedBox(width: 12),
                        Text(
                          "Confirm Selection",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Voice Recognition Info
              SizedBox(height: 32),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Voice commands: Say "Vision", "Hearing", "Speech", "Physical", or "Cognitive" to select an option.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}