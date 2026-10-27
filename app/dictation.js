import { Capacitor, registerPlugin } from "@capacitor/core";
let activeStop = null;
export async function stopDictation() {
  await activeStop?.();
  activeStop = null;
}
export async function startDictation(onText, onState) {
  await stopDictation();
  if (Capacitor.isNativePlatform()) {
    const SpeechRecognition = registerPlugin("NutrientSpeech");
    if (!(await SpeechRecognition.available()).available)
      throw Error(
        "Speech recognition is unavailable on this device. Use the keyboard microphone or type your meal.",
      );
    const permission = await SpeechRecognition.requestPermissions();
    if (permission.speechRecognition !== "granted")
      throw Error(
        "Microphone or speech permission was denied. You can still type your meal.",
      );
    const listener = await SpeechRecognition.addListener(
      "partialResults",
      (data) => {
        if (data.matches?.[0]) onText(data.matches[0]);
      },
    );
    const state = await SpeechRecognition.addListener(
      "listeningState",
      (data) => {
        if (data.status === "stopped") {
          onState(false);
          listener.remove();
          state.remove();
          activeStop = null;
        }
      },
    );
    activeStop = async () => {
      await SpeechRecognition.stop();
      await listener.remove();
      await state.remove();
      onState(false);
    };
    onState(true);
    try {
      await SpeechRecognition.start({
        language: "en-US",
        partialResults: true,
        popup: false,
      });
    } catch (e) {
      await stopDictation();
      throw e;
    }
  } else {
    const Recognition =
      window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!Recognition)
      throw Error(
        "This browser does not support dictation. Use the keyboard microphone on your iPhone, or type your meal.",
      );
    const recognition = new Recognition();
    recognition.lang = "en-US";
    recognition.interimResults = true;
    recognition.continuous = false;
    recognition.onresult = (e) =>
      onText(
        Array.from(e.results)
          .map((r) => r[0].transcript)
          .join(" "),
      );
    recognition.onend = () => {
      onState(false);
      activeStop = null;
    };
    recognition.onerror = () => {
      onState(false);
      activeStop = null;
    };
    activeStop = () => recognition.stop();
    recognition.start();
    onState(true);
  }
}
