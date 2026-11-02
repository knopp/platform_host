package dev.platformhost;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Only used to get hold of the application context when the engine starts.
 *
 * <p>Deliberately not {@code ActivityAware}: the engine is headless and its isolate may serve any
 * number of activities, which are tracked by {@link PHActivities} instead.
 */
public final class PHPlugin implements FlutterPlugin {
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    PHActivities.initialize(binding.getApplicationContext());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
