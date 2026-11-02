package dev.platformhost.platform_host_example;

import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;

// Starts a headless FlutterEngine that isn't tied to any Activity; Dart runs
// on the main looper.
public class Application extends android.app.Application {
  private FlutterEngine engine;

  @Override
  public void onCreate() {
    super.onCreate();

    FlutterInjector.instance().flutterLoader().startInitialization(this);
    FlutterInjector.instance().flutterLoader().ensureInitializationComplete(this, null);

    engine = new FlutterEngine(this);
    engine.getDartExecutor().executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault());
  }

  @Override
  public void onTerminate() {
    if (engine != null) {
      engine.destroy();
      engine = null;
    }
    super.onTerminate();
  }
}
