package dev.platformhost;

import android.annotation.SuppressLint;
import android.content.Context;
import android.view.MotionEvent;
import android.view.View;

/** Forwards the primary pointer's touches to its {@link PHWindow}, in dp. */
@SuppressLint("ViewConstructor")
final class PHTouchView extends View {
  private final PHWindow window;

  PHTouchView(Context context, PHWindow window) {
    super(context);
    this.window = window;
    // iOS's systemTeal, like the UIKit version.
    setBackgroundColor(0xFF30B0C7);
  }

  @Override
  @SuppressLint("ClickableViewAccessibility")
  public boolean onTouchEvent(MotionEvent event) {
    int phase;
    switch (event.getActionMasked()) {
      case MotionEvent.ACTION_DOWN:
        phase = PHWindow.PHASE_BEGAN;
        break;
      case MotionEvent.ACTION_MOVE:
        phase = PHWindow.PHASE_MOVED;
        break;
      case MotionEvent.ACTION_UP:
        phase = PHWindow.PHASE_ENDED;
        break;
      case MotionEvent.ACTION_CANCEL:
        phase = PHWindow.PHASE_CANCELLED;
        break;
      default:
        // Secondary pointers aren't reported.
        return true;
    }
    float density = getResources().getDisplayMetrics().density;
    window.dispatchTouch(phase, event.getX() / density, event.getY() / density);
    return true;
  }
}
