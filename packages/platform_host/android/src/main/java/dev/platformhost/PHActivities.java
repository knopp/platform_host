package dev.platformhost;

import android.app.Activity;
import android.app.Application;
import android.content.Context;
import android.os.Bundle;
import java.util.ArrayList;
import java.util.List;

/**
 * Tracks all of the app's live activities; there is no "current" one.
 *
 * <p>Only activities created after {@link #initialize} are seen. The plugin initializes this while
 * the engine is created in {@code Application.onCreate}, before any activity exists. Main thread
 * only.
 */
final class PHActivities {
  interface Listener {
    void onActivityCreated(Activity activity);

    void onActivityDestroyed(Activity activity);
  }

  private static final List<Activity> activities = new ArrayList<>();
  private static final List<Listener> listeners = new ArrayList<>();
  private static boolean initialized;

  private PHActivities() {}

  static void initialize(Context context) {
    if (initialized) {
      return;
    }
    initialized = true;
    Application application = (Application) context.getApplicationContext();
    application.registerActivityLifecycleCallbacks(
        new Application.ActivityLifecycleCallbacks() {
          @Override
          public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
            activities.add(activity);
            for (Listener listener : new ArrayList<>(listeners)) {
              listener.onActivityCreated(activity);
            }
          }

          @Override
          public void onActivityDestroyed(Activity activity) {
            activities.remove(activity);
            for (Listener listener : new ArrayList<>(listeners)) {
              listener.onActivityDestroyed(activity);
            }
          }

          @Override
          public void onActivityStarted(Activity activity) {}

          @Override
          public void onActivityResumed(Activity activity) {}

          @Override
          public void onActivityPaused(Activity activity) {}

          @Override
          public void onActivityStopped(Activity activity) {}

          @Override
          public void onActivitySaveInstanceState(Activity activity, Bundle outState) {}
        });
  }

  static void checkInitialized() {
    if (!initialized) {
      throw new IllegalStateException(
          "platform_host's plugin (PHPlugin) wasn't registered with the engine");
    }
  }

  /** Live activities, oldest first. */
  static List<Activity> live() {
    return new ArrayList<>(activities);
  }

  static void addListener(Listener listener) {
    listeners.add(listener);
  }

  static void removeListener(Listener listener) {
    listeners.remove(listener);
  }
}
