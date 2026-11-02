package dev.platformhost.automation;

import android.graphics.Point;
import android.graphics.Rect;
import android.os.Bundle;
import android.util.Log;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.By;
import androidx.test.uiautomator.BySelector;
import androidx.test.uiautomator.Direction;
import androidx.test.uiautomator.SearchCondition;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.UiObject2;
import androidx.test.uiautomator.Until;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.WebSocket;
import okhttp3.WebSocketListener;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.junit.Test;
import org.junit.runner.RunWith;

/**
 * UI Automator agent controlled over a WebSocket; executes the UI Automator calls of the Dart mirror
 * (lib/src/uiautomator.dart). The Android counterpart of PAAgent.m, with the same transport.
 *
 * <p>{@link #testServe} connects to the URL in the PA_AGENT_URL instrumentation argument (the Dart
 * test hosts the server) and executes JSON requests until it gets {@code stop} or the connection
 * closes:
 *
 * <pre>
 *   request:  {"id": 1, "method": "UiDevice.findObject", "params": {...}}
 *   response: {"id": 1, "result": <json>} or {"id": 1, "error": "..."}
 * </pre>
 *
 * <p>With PA_AGENT_RECONNECT=1 the agent outlives the app: it keeps connecting (until the app's
 * server is up) and serves one session per app launch, until it's stopped. Otherwise it serves a
 * single session.
 *
 * <p>Methods are {@code <class>.<method>}, named after the Java API (overloads get distinct names
 * or optional params), plus {@code stop}. A UiObject2 is a handle (an index into the session's
 * objects; {@code object} param for its methods). A selector is a list of {@code [method, args...]}
 * criteria, applied in order starting with {@code By.<method>}; a nested list is a selector. Points
 * are {@code [x, y]}, rects {@code [left, top, right, bottom]}, in pixels; times in milliseconds.
 */
@RunWith(AndroidJUnit4.class)
public class PAAgentServer {
  private static final String TAG = "PAAgent";

  /** Marks the end of a connection in the inbox. */
  private static final JSONObject CLOSED = new JSONObject();

  private UiDevice device;
  private final List<UiObject2> objects = new ArrayList<>();

  @Test
  public void testServe() throws InterruptedException {
    Bundle arguments = InstrumentationRegistry.getArguments();
    String url = arguments.getString("PA_AGENT_URL");
    if (url == null) {
      throw new IllegalArgumentException("PA_AGENT_URL is not set");
    }
    boolean reconnect = "1".equals(arguments.getString("PA_AGENT_RECONNECT"));

    device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
    OkHttpClient client = new OkHttpClient.Builder().readTimeout(0, TimeUnit.MILLISECONDS).build();

    while (true) {
      boolean served = serveSession(client, url);
      if (!reconnect) {
        break;
      }
      if (!served) {
        // The app's server isn't up (yet); try again shortly.
        Thread.sleep(250);
      }
    }
  }

  /** Serves one connection. Returns whether any request was handled. */
  private boolean serveSession(OkHttpClient client, String url) throws InterruptedException {
    objects.clear();

    BlockingQueue<JSONObject> inbox = new LinkedBlockingQueue<>();
    // Whether any request was handled; failures before that are just the
    // app's server not being up yet.
    boolean[] served = {false};
    WebSocket socket =
        client.newWebSocket(
            new Request.Builder().url(url).build(),
            new WebSocketListener() {
              @Override
              public void onMessage(WebSocket webSocket, String text) {
                try {
                  inbox.add(new JSONObject(text));
                } catch (JSONException e) {
                  Log.w(TAG, "Invalid request: " + text, e);
                }
              }

              @Override
              public void onClosing(WebSocket webSocket, int code, String reason) {
                Log.i(TAG, "Connection closing: " + code + " " + reason);
                inbox.add(CLOSED);
              }

              @Override
              public void onFailure(WebSocket webSocket, Throwable t, Response response) {
                if (served[0]) {
                  Log.w(TAG, "Connection failed", t);
                }
                inbox.add(CLOSED);
              }
            });

    while (true) {
      JSONObject request = inbox.take();
      if (request == CLOSED) {
        break;
      }
      if (!served[0]) {
        Log.i(TAG, "Connected to " + url);
      }
      served[0] = true;
      boolean stop = "stop".equals(request.optString("method"));
      socket.send(handle(request).toString());
      if (stop) {
        break;
      }
    }
    socket.close(1000, null);
    return served[0];
  }

  // Requests

  private JSONObject handle(JSONObject request) {
    Object id = request.opt("id");
    JSONObject response = new JSONObject();
    try {
      response.put("id", id == null ? JSONObject.NULL : id);
      try {
        JSONObject params = request.optJSONObject("params");
        Object result =
            perform(request.optString("method"), params == null ? new JSONObject() : params);
        response.put("result", result == null ? JSONObject.NULL : result);
      } catch (Throwable t) {
        if (t instanceof InvocationTargetException) {
          t = t.getCause();
        }
        response.put("error", t.getClass().getSimpleName() + ": " + t.getMessage());
      }
    } catch (JSONException e) {
      throw new IllegalStateException(e);
    }
    return response;
  }

  private Object perform(String method, JSONObject params) throws Exception {
    if (method.equals("stop")) {
      return null;
    }
    if (method.startsWith("UiDevice.")) {
      return device(method.substring("UiDevice.".length()), params);
    }
    if (method.startsWith("UiObject2.")) {
      return object(method.substring("UiObject2.".length()), params);
    }
    throw new IllegalArgumentException("Unknown method '" + method + "'");
  }

  private Object device(String method, JSONObject params) throws Exception {
    switch (method) {
      case "getDisplayWidth":
        return device.getDisplayWidth();
      case "getDisplayHeight":
        return device.getDisplayHeight();
      case "getDisplaySizeDp":
        return pointJson(device.getDisplaySizeDp());
      case "getDisplayRotation":
        return device.getDisplayRotation();
      case "getCurrentPackageName":
        return device.getCurrentPackageName();
      case "getProductName":
        return device.getProductName();
      case "hasObject":
        return device.hasObject(selector(params.getJSONArray("selector")));
      case "findObject":
        return objectJson(device.findObject(selector(params.getJSONArray("selector"))));
      case "findObjects":
        return objectsJson(device.findObjects(selector(params.getJSONArray("selector"))));
      case "wait":
        return waitFor(params);
      case "waitForIdle":
        if (params.has("timeout")) {
          device.waitForIdle(params.getLong("timeout"));
        } else {
          device.waitForIdle();
        }
        return null;
      case "click":
        return device.click(params.getInt("x"), params.getInt("y"));
      case "swipe":
        return device.swipe(
            params.getInt("startX"),
            params.getInt("startY"),
            params.getInt("endX"),
            params.getInt("endY"),
            params.getInt("steps"));
      case "swipeSegments":
        {
          JSONArray json = params.getJSONArray("segments");
          Point[] segments = new Point[json.length()];
          for (int i = 0; i < segments.length; i++) {
            segments[i] = point(json.getJSONArray(i));
          }
          return device.swipe(segments, params.getInt("segmentSteps"));
        }
      case "drag":
        return device.drag(
            params.getInt("startX"),
            params.getInt("startY"),
            params.getInt("endX"),
            params.getInt("endY"),
            params.getInt("steps"));
      case "pressBack":
        return device.pressBack();
      case "pressHome":
        return device.pressHome();
      case "pressEnter":
        return device.pressEnter();
      case "pressKeyCode":
        return device.pressKeyCode(params.getInt("keyCode"));
      default:
        throw new IllegalArgumentException("Unknown method 'UiDevice." + method + "'");
    }
  }

  private Object waitFor(JSONObject params) throws JSONException {
    BySelector selector = selector(params.getJSONArray("selector"));
    long timeout = params.getLong("timeout");
    String condition = params.getString("condition");
    switch (condition) {
      case "hasObject":
        return Boolean.TRUE.equals(device.wait(Until.hasObject(selector), timeout));
      case "gone":
        return Boolean.TRUE.equals(device.wait(Until.gone(selector), timeout));
      case "findObject":
        return objectJson(device.wait(Until.findObject(selector), timeout));
      case "findObjects":
        {
          SearchCondition<List<UiObject2>> findObjects = Until.findObjects(selector);
          List<UiObject2> found = device.wait(findObjects, timeout);
          return objectsJson(found == null ? new ArrayList<>() : found);
        }
      default:
        throw new IllegalArgumentException("Unknown condition 'Until." + condition + "'");
    }
  }

  private Object object(String method, JSONObject params) throws Exception {
    int handle = params.optInt("object", -1);
    if (handle < 0 || handle >= objects.size() || objects.get(handle) == null) {
      throw new IllegalArgumentException("Unknown object handle " + params.opt("object"));
    }
    UiObject2 object = objects.get(handle);
    switch (method) {
      case "getVisibleBounds":
        return rectJson(object.getVisibleBounds());
      case "getVisibleCenter":
        return pointJson(object.getVisibleCenter());
      case "getApplicationPackage":
        return object.getApplicationPackage();
      case "getClassName":
        return object.getClassName();
      case "getContentDescription":
        return object.getContentDescription();
      case "getResourceName":
        return object.getResourceName();
      case "getText":
        return object.getText();
      case "getDisplayId":
        return object.getDisplayId();
      case "isCheckable":
        return object.isCheckable();
      case "isChecked":
        return object.isChecked();
      case "isClickable":
        return object.isClickable();
      case "isEnabled":
        return object.isEnabled();
      case "isFocusable":
        return object.isFocusable();
      case "isFocused":
        return object.isFocused();
      case "isLongClickable":
        return object.isLongClickable();
      case "isScrollable":
        return object.isScrollable();
      case "isSelected":
        return object.isSelected();
      case "getParent":
        return objectJson(object.getParent());
      case "getChildCount":
        return object.getChildCount();
      case "getChildren":
        return objectsJson(object.getChildren());
      case "hasObject":
        return object.hasObject(selector(params.getJSONArray("selector")));
      case "findObject":
        return objectJson(object.findObject(selector(params.getJSONArray("selector"))));
      case "findObjects":
        return objectsJson(object.findObjects(selector(params.getJSONArray("selector"))));
      case "click":
        if (params.has("duration")) {
          object.click(params.getLong("duration"));
        } else {
          object.click();
        }
        return null;
      case "longClick":
        object.longClick();
        return null;
      case "drag":
        if (params.has("speed")) {
          object.drag(point(params.getJSONArray("dest")), params.getInt("speed"));
        } else {
          object.drag(point(params.getJSONArray("dest")));
        }
        return null;
      case "swipe":
        if (params.has("speed")) {
          object.swipe(
              direction(params), (float) params.getDouble("percent"), params.getInt("speed"));
        } else {
          object.swipe(direction(params), (float) params.getDouble("percent"));
        }
        return null;
      case "scroll":
        return params.has("speed")
            ? object.scroll(
                direction(params), (float) params.getDouble("percent"), params.getInt("speed"))
            : object.scroll(direction(params), (float) params.getDouble("percent"));
      case "fling":
        return params.has("speed")
            ? object.fling(direction(params), params.getInt("speed"))
            : object.fling(direction(params));
      case "setText":
        object.setText(params.getString("text"));
        return null;
      case "clear":
        object.clear();
        return null;
      case "recycle":
        object.recycle();
        objects.set(handle, null);
        return null;
      default:
        throw new IllegalArgumentException("Unknown method 'UiObject2." + method + "'");
    }
  }

  // Values

  /**
   * Builds a selector: the first criterion through By, the rest through BySelector, both by
   * reflection, with argument types from the JSON (string, boolean, int, nested selector).
   */
  private BySelector selector(JSONArray criteria) throws JSONException {
    BySelector selector = null;
    for (int i = 0; i < criteria.length(); i++) {
      JSONArray criterion = criteria.getJSONArray(i);
      String name = criterion.getString(0);
      Class<?>[] types = new Class<?>[criterion.length() - 1];
      Object[] args = new Object[types.length];
      for (int j = 0; j < args.length; j++) {
        Object arg = criterion.get(j + 1);
        if (arg instanceof JSONArray) {
          args[j] = selector((JSONArray) arg);
          types[j] = BySelector.class;
        } else if (arg instanceof Boolean) {
          args[j] = arg;
          types[j] = boolean.class;
        } else if (arg instanceof Integer) {
          args[j] = arg;
          types[j] = int.class;
        } else {
          args[j] = arg.toString();
          types[j] = String.class;
        }
      }
      try {
        Method method = (selector == null ? By.class : BySelector.class).getMethod(name, types);
        selector = (BySelector) method.invoke(selector, args);
      } catch (NoSuchMethodException | IllegalAccessException e) {
        throw new IllegalArgumentException("Unknown selector criterion " + criterion, e);
      } catch (InvocationTargetException e) {
        throw new IllegalArgumentException(
            "Invalid selector criterion " + criterion + ": " + e.getCause().getMessage(), e);
      }
    }
    if (selector == null) {
      throw new IllegalArgumentException("Empty selector");
    }
    return selector;
  }

  private static Direction direction(JSONObject params) throws JSONException {
    // Same order as the Dart enum.
    Direction[] directions = {Direction.LEFT, Direction.RIGHT, Direction.UP, Direction.DOWN};
    return directions[params.getInt("direction")];
  }

  private static Point point(JSONArray json) throws JSONException {
    return new Point(json.getInt(0), json.getInt(1));
  }

  private static JSONArray pointJson(Point point) {
    return new JSONArray().put(point.x).put(point.y);
  }

  private static JSONArray rectJson(Rect rect) {
    return new JSONArray().put(rect.left).put(rect.top).put(rect.right).put(rect.bottom);
  }

  private Object objectJson(UiObject2 object) {
    if (object == null) {
      return null;
    }
    objects.add(object);
    return objects.size() - 1;
  }

  private JSONArray objectsJson(List<UiObject2> list) {
    JSONArray json = new JSONArray();
    for (UiObject2 object : list) {
      json.put(objectJson(object));
    }
    return json;
  }
}
