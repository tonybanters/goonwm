pub const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/Xutil.h");
    @cInclude("X11/Xatom.h");
    @cInclude("X11/cursorfont.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/extensions/Xinerama.h");
});

pub const Display = c.Display;
pub const Window = c.Window;
pub const XEvent = c.XEvent;
pub const XWindowAttributes = c.XWindowAttributes;
pub const XWindowChanges = c.XWindowChanges;
pub const XMapRequestEvent = c.XMapRequestEvent;
pub const XConfigureRequestEvent = c.XConfigureRequestEvent;
pub const XKeyEvent = c.XKeyEvent;
pub const XDestroyWindowEvent = c.XDestroyWindowEvent;
pub const XUnmapEvent = c.XUnmapEvent;
pub const XCrossingEvent = c.XCrossingEvent;
pub const XErrorEvent = c.XErrorEvent;
pub const KeySym = c.KeySym;

pub const XOpenDisplay = c.XOpenDisplay;
pub const XCloseDisplay = c.XCloseDisplay;
pub const XDefaultScreen = c.XDefaultScreen;
pub const XRootWindow = c.XRootWindow;
pub const XDisplayWidth = c.XDisplayWidth;
pub const XDisplayHeight = c.XDisplayHeight;
pub const XNextEvent = c.XNextEvent;
pub const XPending = c.XPending;
pub const XSync = c.XSync;
pub const XSelectInput = c.XSelectInput;
pub const XSetErrorHandler = c.XSetErrorHandler;
pub const XGrabKey = c.XGrabKey;
pub const XKeysymToKeycode = c.XKeysymToKeycode;
pub const XKeycodeToKeysym = c.XKeycodeToKeysym;
pub const XQueryTree = c.XQueryTree;
pub const XFree = c.XFree;
pub const XGetWindowAttributes = c.XGetWindowAttributes;
pub const XMapWindow = c.XMapWindow;
pub const XConfigureWindow = c.XConfigureWindow;
pub const XSetInputFocus = c.XSetInputFocus;
pub const XRaiseWindow = c.XRaiseWindow;
pub const XMoveResizeWindow = c.XMoveResizeWindow;
pub const XMoveWindow = c.XMoveWindow;
pub const XSetWindowBorder = c.XSetWindowBorder;
pub const XSetWindowBorderWidth = c.XSetWindowBorderWidth;

pub const SubstructureRedirectMask = c.SubstructureRedirectMask;
pub const SubstructureNotifyMask = c.SubstructureNotifyMask;
pub const EnterWindowMask = c.EnterWindowMask;
pub const FocusChangeMask = c.FocusChangeMask;
pub const PropertyChangeMask = c.PropertyChangeMask;
pub const StructureNotifyMask = c.StructureNotifyMask;

pub const Mod4Mask = c.Mod4Mask;
pub const ShiftMask = c.ShiftMask;

pub const GrabModeAsync = c.GrabModeAsync;
pub const RevertToPointerRoot = c.RevertToPointerRoot;
pub const CurrentTime = c.CurrentTime;
pub const NotifyNormal = c.NotifyNormal;

pub const True = c.True;
pub const False = c.False;

pub const XK_q = c.XK_q;
pub const XK_f = c.XK_f;
pub const XK_j = c.XK_j;
pub const XK_k = c.XK_k;
pub const XK_space = c.XK_space;
pub const XK_Return = c.XK_Return;
pub const XK_1 = c.XK_1;
pub const XK_2 = c.XK_2;
pub const XK_3 = c.XK_3;
pub const XK_4 = c.XK_4;
pub const XK_5 = c.XK_5;
pub const XK_6 = c.XK_6;
pub const XK_7 = c.XK_7;
pub const XK_8 = c.XK_8;
pub const XK_9 = c.XK_9;

pub const Mod1Mask = c.Mod1Mask;

pub const XKillClient = c.XKillClient;
pub const XInternAtom = c.XInternAtom;
pub const XChangeProperty = c.XChangeProperty;
pub const XGetWindowProperty = c.XGetWindowProperty;
pub const XSendEvent = c.XSendEvent;

pub const Atom = c.Atom;
pub const XA_ATOM = c.XA_ATOM;
pub const XClientMessageEvent = c.XClientMessageEvent;

pub const PropModeReplace = c.PropModeReplace;

pub const KeyPress = c.KeyPress;
pub const KeyRelease = c.KeyRelease;
pub const ButtonPress = c.ButtonPress;
pub const ButtonRelease = c.ButtonRelease;
pub const MotionNotify = c.MotionNotify;
pub const EnterNotify = c.EnterNotify;
pub const LeaveNotify = c.LeaveNotify;
pub const FocusIn = c.FocusIn;
pub const FocusOut = c.FocusOut;
pub const KeymapNotify = c.KeymapNotify;
pub const Expose = c.Expose;
pub const GraphicsExpose = c.GraphicsExpose;
pub const NoExpose = c.NoExpose;
pub const VisibilityNotify = c.VisibilityNotify;
pub const CreateNotify = c.CreateNotify;
pub const DestroyNotify = c.DestroyNotify;
pub const UnmapNotify = c.UnmapNotify;
pub const MapNotify = c.MapNotify;
pub const MapRequest = c.MapRequest;
pub const ReparentNotify = c.ReparentNotify;
pub const ConfigureNotify = c.ConfigureNotify;
pub const ConfigureRequest = c.ConfigureRequest;
pub const GravityNotify = c.GravityNotify;
pub const ResizeRequest = c.ResizeRequest;
pub const CirculateNotify = c.CirculateNotify;
pub const CirculateRequest = c.CirculateRequest;
pub const PropertyNotify = c.PropertyNotify;
pub const SelectionClear = c.SelectionClear;
pub const SelectionRequest = c.SelectionRequest;
pub const SelectionNotify = c.SelectionNotify;
pub const ColormapNotify = c.ColormapNotify;
pub const ClientMessage = c.ClientMessage;
pub const MappingNotify = c.MappingNotify;
pub const GenericEvent = c.GenericEvent;
