import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../core/models/stylist_chat_model.dart';
import '../core/network/api_client.dart';
import '../core/utils/speech_cleaner.dart';

/// Explicit lifecycle states for voice interaction
enum VoiceState {
  idle,
  listening,
  finalizing,
  submitting,
  waitingForResponse,
  speaking,
  resumingListening,
  error,
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessageModel> _messages = [];
  bool _isThinking = false;
  String? _error;
  String? _lastUserPrompt;

  // Voice Interaction State
  stt.SpeechToText? _speech;
  FlutterTts? _tts;
  bool _isVoiceInitialized = false;
  bool _isVoiceAvailable = false;
  bool _isTtsInitialized = false;

  VoiceState _voiceState = VoiceState.idle;
  String _voiceStatus = '';
  String _liveTranscript = '';

  // Mode and Preference Flags
  bool _isHandsFreeMode = false;
  bool _autoVoiceRepliesEnabled = true;

  // TTS State
  bool _isSpeaking = false;
  bool _isTtsPaused = false;
  String? _currentlySpeakingMessageId;

  // Timers and Guards for End-of-Speech Detection
  Timer? _silenceTimer;
  Timer? _resumeTimer;
  int _activeVoiceSessionId = 0;
  bool _isSubmittingVoice = false;

  List<ChatMessageModel> get messages => List.unmodifiable(_messages);
  bool get isThinking => _isThinking;
  bool get isListening => _voiceState == VoiceState.listening;
  bool get isSpeaking => _isSpeaking;
  bool get isTtsPaused => _isTtsPaused;
  bool get isHandsFreeMode => _isHandsFreeMode;
  bool get autoVoiceRepliesEnabled => _autoVoiceRepliesEnabled;

  VoiceState get voiceState => _voiceState;
  String get voiceStatus => _voiceStatus;
  String get liveTranscript => _liveTranscript;
  String? get currentlySpeakingMessageId => _currentlySpeakingMessageId;
  bool get isVoiceAvailable => _isVoiceAvailable;
  String? get error => _error;
  String? get lastUserPrompt => _lastUserPrompt;

  static const List<String> starterPrompts = [
    'Style an outfit for dinner tonight',
    'How can I wear my blazer casually?',
    'What staples is my wardrobe missing?',
    'How should I pack for a 3-day trip?',
  ];

  void setVoiceStatus(String status) {
    _voiceStatus = status;
    notifyListeners();
  }

  void setLiveTranscript(String transcript) {
    _liveTranscript = transcript;
    notifyListeners();
  }

  void setAutoVoiceReplies(bool enabled) {
    _autoVoiceRepliesEnabled = enabled;
    notifyListeners();
  }

  void clearChat() {
    stopAllVoice();
    _messages.clear();
    _error = null;
    _lastUserPrompt = null;
    _voiceStatus = '';
    _liveTranscript = '';
    _voiceState = VoiceState.idle;
    notifyListeners();
  }

  void addMessageForTesting(ChatMessageModel message) {
    _messages.add(message);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Speech-To-Text (STT) Engine & End-of-Speech Detection
  // ---------------------------------------------------------------------------

  Future<bool> initSpeech() async {
    if (_isVoiceInitialized && _speech != null) {
      return _isVoiceAvailable;
    }

    try {
      _speech ??= stt.SpeechToText();
      final hasPermission = await _speech!.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: kDebugMode,
      );
      _isVoiceInitialized = true;
      _isVoiceAvailable = hasPermission;
      return hasPermission;
    } catch (e) {
      debugPrint('Speech recognition initialization notice: $e');
      _isVoiceInitialized = true;
      _isVoiceAvailable = false;
      return false;
    }
  }

  void _onSpeechStatus(String status) {
    debugPrint('Speech recognition status event: $status');
    if (status == 'listening') {
      if (_voiceState != VoiceState.finalizing && _voiceState != VoiceState.submitting) {
        _voiceState = VoiceState.listening;
        _voiceStatus = _isHandsFreeMode ? 'Hands-free Mode • Listening...' : 'Listening...';
        notifyListeners();
      }
    } else if (status == 'notListening' || status == 'done') {
      // If recognition engine stopped while user was speaking, finalize transcript
      if (_voiceState == VoiceState.listening) {
        _handleEndOfSpeech(fromFinalResult: false);
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError errorNotification) {
    debugPrint('Speech recognition error event: ${errorNotification.errorMsg}');
    _silenceTimer?.cancel();

    final errMsg = errorNotification.errorMsg.toLowerCase();
    if (errMsg.contains('denied') || errMsg.contains('permission')) {
      _voiceState = VoiceState.error;
      _voiceStatus = 'Microphone permission denied. Please allow microphone access.';
      _isHandsFreeMode = false;
    } else if (errMsg.contains('no_match') || errMsg.contains('speech_timeout')) {
      if (_liveTranscript.trim().isNotEmpty) {
        // Recover transcript even on timeout
        _handleEndOfSpeech(fromFinalResult: true);
        return;
      }
      _voiceState = VoiceState.idle;
      _voiceStatus = "Couldn't hear that. Try again.";
    } else {
      _voiceState = VoiceState.error;
      _voiceStatus = "Voice input stopped: ${errorNotification.errorMsg}";
      _isHandsFreeMode = false;
    }
    notifyListeners();
  }

  /// Starts capturing speech from the microphone
  Future<void> startListening({
    ValueChanged<String>? onTranscriptUpdate,
  }) async {
    // If TTS is currently speaking, stop it before listening to prevent echo loop
    if (_isSpeaking) {
      await stopSpeaking();
    }

    if (_voiceState == VoiceState.submitting || _voiceState == VoiceState.waitingForResponse) {
      return;
    }

    _activeVoiceSessionId++;
    final currentSession = _activeVoiceSessionId;
    _isSubmittingVoice = false;
    _silenceTimer?.cancel();
    _resumeTimer?.cancel();

    _error = null;
    _voiceState = VoiceState.listening;
    _voiceStatus = _isHandsFreeMode ? 'Hands-free Mode • Connecting...' : 'Connecting microphone...';
    _liveTranscript = '';
    notifyListeners();

    final available = await initSpeech();
    if (!available || currentSession != _activeVoiceSessionId) {
      _voiceState = VoiceState.error;
      _voiceStatus = 'Speech recognition is not available or permission was denied on this platform.';
      _isHandsFreeMode = false;
      notifyListeners();
      return;
    }

    _voiceStatus = _isHandsFreeMode ? 'Hands-free Mode • Listening...' : 'Listening...';
    notifyListeners();

    try {
      await _speech!.listen(
        onResult: (result) {
          if (currentSession != _activeVoiceSessionId) return;

          _liveTranscript = result.recognizedWords;
          if (onTranscriptUpdate != null) {
            onTranscriptUpdate(_liveTranscript);
          }
          notifyListeners();

          // Reset silence debounce on every active speech update
          _silenceTimer?.cancel();

          if (result.finalResult && _liveTranscript.trim().isNotEmpty) {
            // Engine detected definite end of sentence/utterance
            _handleEndOfSpeech(fromFinalResult: true);
          } else if (_liveTranscript.trim().isNotEmpty) {
            // Natural pause detection: auto-submit if user pauses for 1800ms
            _silenceTimer = Timer(const Duration(milliseconds: 1800), () {
              if (currentSession == _activeVoiceSessionId && _voiceState == VoiceState.listening) {
                _handleEndOfSpeech(fromFinalResult: true);
              }
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
        ),
      );
    } catch (e) {
      _voiceState = VoiceState.error;
      _voiceStatus = 'Unable to access microphone: $e';
      _isHandsFreeMode = false;
      notifyListeners();
    }
  }

  /// Internal handler for end-of-speech detection and submission
  Future<void> _handleEndOfSpeech({required bool fromFinalResult}) async {
    _silenceTimer?.cancel();

    if (_isSubmittingVoice) return;
    final text = _liveTranscript.trim();

    if (text.isEmpty) {
      _voiceState = VoiceState.idle;
      _voiceStatus = "Couldn't hear that. Try again.";
      try {
        if (_speech != null && _speech!.isListening) {
          await _speech!.stop();
        }
      } catch (_) {}
      notifyListeners();
      return;
    }

    // Lock submission gate to prevent duplicate chat requests
    _isSubmittingVoice = true;
    _voiceState = VoiceState.finalizing;
    _voiceStatus = 'Finalizing your request...';
    notifyListeners();

    try {
      if (_speech != null && _speech!.isListening) {
        await _speech!.stop();
      }
    } catch (_) {}

    _voiceState = VoiceState.submitting;
    _voiceStatus = 'Processing request...';
    _liveTranscript = '';
    notifyListeners();

    await sendMessage(text);
    _isSubmittingVoice = false;
  }

  /// Manually stops capturing speech and submits the current transcript
  Future<void> stopListening({bool submit = true}) async {
    _silenceTimer?.cancel();

    try {
      if (_speech != null && _speech!.isListening) {
        await _speech!.stop();
      }
    } catch (_) {}

    if (submit && _liveTranscript.trim().isNotEmpty) {
      await _handleEndOfSpeech(fromFinalResult: true);
    } else if (submit) {
      _voiceState = VoiceState.idle;
      _liveTranscript = '';
      _voiceStatus = "Couldn't hear that. Try again.";
      notifyListeners();
    } else {
      _voiceState = VoiceState.idle;
      _liveTranscript = '';
      _voiceStatus = '';
      notifyListeners();
    }
  }

  /// Cancels listening and discards current transcript without submitting
  Future<void> cancelListening() async {
    _silenceTimer?.cancel();
    _resumeTimer?.cancel();
    _activeVoiceSessionId++;
    _isSubmittingVoice = false;

    _voiceState = VoiceState.idle;
    _liveTranscript = '';
    _voiceStatus = '';

    try {
      if (_speech != null && _speech!.isListening) {
        await _speech!.cancel();
      }
    } catch (_) {}
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Text-To-Speech (TTS) Engine
  // ---------------------------------------------------------------------------

  Future<bool> initTts() async {
    if (_isTtsInitialized && _tts != null) return true;

    try {
      _tts ??= FlutterTts();
      await _tts!.setLanguage('en-US');
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);

      _tts!.setStartHandler(() {
        _isSpeaking = true;
        _isTtsPaused = false;
        _voiceState = VoiceState.speaking;
        notifyListeners();
      });

      _tts!.setCompletionHandler(() {
        _onTtsComplete();
      });

      _tts!.setCancelHandler(() {
        _isSpeaking = false;
        _isTtsPaused = false;
        _currentlySpeakingMessageId = null;
        if (_voiceState == VoiceState.speaking) {
          _voiceState = VoiceState.idle;
        }
        notifyListeners();
      });

      _tts!.setErrorHandler((msg) {
        debugPrint('TTS synthesis error: $msg');
        _isSpeaking = false;
        _isTtsPaused = false;
        _currentlySpeakingMessageId = null;
        if (_voiceState == VoiceState.speaking) {
          _voiceState = VoiceState.idle;
        }
        notifyListeners();
      });

      _isTtsInitialized = true;
      return true;
    } catch (e) {
      debugPrint('TTS engine initialization notice: $e');
      _isTtsInitialized = false;
      return false;
    }
  }

  /// Speaks a specific message aloud using clean spoken-content rules
  Future<void> speakMessage(ChatMessageModel message) async {
    if (!message.isAssistant) return;

    // Echo Prevention: Ensure microphone is stopped before speaking begins
    if (_voiceState == VoiceState.listening) {
      await stopListening(submit: false);
    }

    // Stop any existing speech playback to prevent overlaps
    if (_isSpeaking) {
      await stopSpeaking();
    }

    final cleanText = SpeechCleaner.cleanForSpeech(message.content);
    if (cleanText.isEmpty) return;

    final available = await initTts();
    if (!available) {
      debugPrint('TTS unavailable on this platform');
      return;
    }

    _currentlySpeakingMessageId = message.id;
    _isSpeaking = true;
    _isTtsPaused = false;
    _voiceState = VoiceState.speaking;
    _voiceStatus = _isHandsFreeMode ? 'Hands-free Mode • Speaking response...' : 'adaa is speaking...';
    notifyListeners();

    try {
      await _tts!.speak(cleanText);
    } catch (e) {
      debugPrint('Failed to speak response: $e');
      _isSpeaking = false;
      _currentlySpeakingMessageId = null;
      _voiceState = VoiceState.idle;
      notifyListeners();
    }
  }

  /// Pauses current TTS speech
  Future<void> pauseSpeaking() async {
    if (!_isSpeaking) return;
    try {
      await _tts?.pause();
      _isTtsPaused = true;
      notifyListeners();
    } catch (_) {}
  }

  /// Resumes paused TTS speech
  Future<void> resumeSpeaking() async {
    if (!_isTtsPaused || _currentlySpeakingMessageId == null) return;
    final msg = _messages.firstWhere(
      (m) => m.id == _currentlySpeakingMessageId,
      orElse: () => _messages.last,
    );
    await speakMessage(msg);
  }

  /// Stops TTS playback cleanly
  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    _isTtsPaused = false;
    _currentlySpeakingMessageId = null;
    try {
      await _tts?.stop();
    } catch (_) {}

    if (_voiceState == VoiceState.speaking) {
      _voiceState = VoiceState.idle;
      _voiceStatus = '';
    }
    notifyListeners();
  }

  /// Callback when speech playback finishes naturally
  void _onTtsComplete() {
    _isSpeaking = false;
    _isTtsPaused = false;
    _currentlySpeakingMessageId = null;

    if (_isHandsFreeMode) {
      // Safe Echo Prevention Transition:
      // Wait 650ms after TTS completes so acoustic reflections settle before opening mic
      _voiceState = VoiceState.resumingListening;
      _voiceStatus = 'Hands-free Mode • Listening in a moment...';
      notifyListeners();

      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(milliseconds: 650), () {
        if (_isHandsFreeMode && !_isSpeaking) {
          startListening();
        }
      });
    } else {
      _voiceState = VoiceState.idle;
      _voiceStatus = '';
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Hands-Free Conversation Mode
  // ---------------------------------------------------------------------------

  /// Enables or disables continuous hands-free turn-taking conversation
  void setHandsFreeMode(bool enabled) {
    if (_isHandsFreeMode == enabled) return;

    _isHandsFreeMode = enabled;
    if (_isHandsFreeMode) {
      _autoVoiceRepliesEnabled = true;
      _voiceStatus = 'Hands-free Mode activated';
      notifyListeners();

      // Start first turn
      if (_voiceState == VoiceState.idle) {
        startListening();
      }
    } else {
      // Exiting hands-free mode stops all active listening and timers
      _resumeTimer?.cancel();
      _silenceTimer?.cancel();
      if (_voiceState == VoiceState.listening) {
        cancelListening();
      }
      _voiceStatus = 'Hands-free Mode disabled';
      notifyListeners();
    }
  }

  /// Stops all active audio (microphone, TTS, timers)
  void stopAllVoice() {
    _resumeTimer?.cancel();
    _silenceTimer?.cancel();
    _activeVoiceSessionId++;
    _isSubmittingVoice = false;

    try {
      _speech?.cancel();
    } catch (_) {}
    try {
      _tts?.stop();
    } catch (_) {}

    _isSpeaking = false;
    _isTtsPaused = false;
    _currentlySpeakingMessageId = null;
    _voiceState = VoiceState.idle;
    _liveTranscript = '';
    _voiceStatus = '';
    notifyListeners();
  }

  void resetVoiceStatus() {
    _voiceStatus = '';
    _liveTranscript = '';
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Chat Messaging Core
  // ---------------------------------------------------------------------------

  Future<void> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty || _isThinking) return;

    _lastUserPrompt = cleanText;
    _error = null;

    // Add user message to UI
    _messages.add(
      ChatMessageModel(
        role: 'user',
        content: cleanText,
      ),
    );
    _isThinking = true;
    _voiceState = VoiceState.waitingForResponse;
    _voiceStatus = _isHandsFreeMode ? 'Hands-free Mode • adaa is thinking...' : 'adaa is thinking...';
    notifyListeners();

    try {
      // Build history context (last 6 items before this user message)
      final historyPayload = _messages
          .sublist(0, _messages.length - 1)
          .take(6)
          .map((m) => m.toRequestHistoryJson())
          .toList();

      final response = await ApiClient.sendStylistChat(
        message: cleanText,
        history: historyPayload,
      );

      final assistantMessage = ChatMessageModel(
        role: 'assistant',
        content: response.reply,
        suggestedItems: response.suggestedItems,
        suggestedAcquisitions: response.suggestedAcquisitions,
        actions: response.actions,
        domainStatus: response.domainStatus,
      );

      _messages.add(assistantMessage);

      // Automatic spoken reply if enabled or in hands-free mode
      if (_autoVoiceRepliesEnabled || _isHandsFreeMode) {
        await speakMessage(assistantMessage);
      } else {
        _voiceState = VoiceState.idle;
        _voiceStatus = '';
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _voiceState = VoiceState.error;
      _voiceStatus = 'Stylist request failed. Tap retry.';
      _isHandsFreeMode = false;
    } finally {
      _isThinking = false;
      notifyListeners();
    }
  }

  Future<void> retryLastMessage() async {
    if (_lastUserPrompt != null && _lastUserPrompt!.isNotEmpty) {
      if (_messages.isNotEmpty && _messages.last.isUser) {
        _messages.removeLast();
      }
      await sendMessage(_lastUserPrompt!);
    }
  }

  // ---------------------------------------------------------------------------
  // Simulation Helpers for Unit / Widget Tests
  // ---------------------------------------------------------------------------

  void simulateVoiceTranscript(String transcript, {bool autoSubmit = true}) {
    _voiceState = VoiceState.listening;
    _liveTranscript = transcript;
    _voiceStatus = 'Listening...';
    notifyListeners();

    if (autoSubmit) {
      _handleEndOfSpeech(fromFinalResult: true);
    }
  }

  void simulateVoiceError(String errorStatus) {
    _voiceState = VoiceState.error;
    _voiceStatus = errorStatus;
    _liveTranscript = '';
    notifyListeners();
  }

  void simulateTtsPlayback({
    required String messageId,
    VoidCallback? onComplete,
  }) {
    _currentlySpeakingMessageId = messageId;
    _isSpeaking = true;
    _voiceState = VoiceState.speaking;
    _voiceStatus = 'adaa is speaking...';
    notifyListeners();

    if (onComplete != null) {
      onComplete();
    }
  }

  @override
  void dispose() {
    stopAllVoice();
    super.dispose();
  }
}
