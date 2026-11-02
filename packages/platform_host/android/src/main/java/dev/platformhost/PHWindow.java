package dev.platformhost;

import android.app.Activity;
import android.view.ViewGroup;

/**
 * A single view, shown as the content of an activity, that reports touches.
 *
 * <p>The view is shown in the oldest live activity, or in the next one created if there is none
 * yet (Dart starts before the launcher activity). Once that activity is destroyed the window stays
 * detached. Main thread only.
 */
public final class PHWindow {
  public static final int PHASE_BEGAN = 0;
  public static final int PHASE_MOVED = 1;
  public static final int PHASE_ENDED = 2;
  public static final int PHASE_CANCELLED = 3;

  /** Receives touches; coordinates are in dp, relative to the view's top-left corner. */
  public interface TouchListener {
    void onTouch(int phase, double x, double y);
  }

  private final PHActivities.Listener activityListener =
      new PHActivities.Listener() {
        @Override
        public void onActivityCreated(Activity activity) {
          if (PHWindow.this.activity == null && !closed) {
            attach(activity);
          }
        }

        @Override
        public void onActivityDestroyed(Activity activity) {
          if (activity == PHWindow.this.activity) {
            detach();
          }
        }
      };

  private Activity activity;
  private PHTouchView view;
  private TouchListener touchListener;
  private String identifier;
  private boolean closed;

  public PHWindow() {
    PHActivities.checkInitialized();
    PHActivities.addListener(activityListener);
    for (Activity activity : PHActivities.live()) {
      attach(activity);
      break;
    }
  }

  public void setTouchListener(TouchListener listener) {
    touchListener = listener;
  }

  /** Content description of the view, used by UI automation to find it. */
  public String getIdentifier() {
    return identifier;
  }

  public void setIdentifier(String identifier) {
    this.identifier = identifier;
    if (view != null) {
      view.setContentDescription(identifier);
    }
  }

  /** Removes the view from its activity and stops delivering touches. */
  public void close() {
    if (closed) {
      return;
    }
    closed = true;
    touchListener = null;
    PHActivities.removeListener(activityListener);
    if (view != null && view.getParent() instanceof ViewGroup) {
      ((ViewGroup) view.getParent()).removeView(view);
    }
    detach();
  }

  void dispatchTouch(int phase, double x, double y) {
    if (touchListener != null) {
      touchListener.onTouch(phase, x, y);
    }
  }

  private void attach(Activity activity) {
    this.activity = activity;
    view = new PHTouchView(activity, this);
    view.setContentDescription(identifier);
    activity.setContentView(view);
  }

  private void detach() {
    activity = null;
    view = null;
  }
}
