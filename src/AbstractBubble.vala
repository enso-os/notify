/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
*/

public class Notify.AbstractBubble : Gtk.Window {
    public signal void closed (uint32 reason);

    protected Gtk.Stack content_area;
    protected Gtk.HeaderBar headerbar;
    protected Gtk.Grid draw_area;

    private Gtk.Revealer revealer;
    private uint timeout_id;
    //  private Hdy.Carousel carousel;

    construct {
        content_area = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.SLIDE_DOWN,
            vhomogeneous = false
        };

        draw_area = new Gtk.Grid () {
            hexpand = true,
            margin = 16
        };
        draw_area.get_style_context ().add_class ("gala-notification");
        draw_area.add (content_area);

        var close_button = new Gtk.Button.from_icon_name ("window-close-symbolic", Gtk.IconSize.LARGE_TOOLBAR) {
            halign = Gtk.Align.START,
            valign = Gtk.Align.START
        };
        close_button.get_style_context ().add_class ("notify-close");

        var close_revealer = new Gtk.Revealer () {
            reveal_child = false,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        close_revealer.add (close_button);

        var overlay = new Gtk.Overlay ();
        overlay.add (draw_area);
        overlay.add_overlay (close_revealer);

        revealer = new Gtk.Revealer () {
            reveal_child = true,
            transition_duration = 195,
            transition_type = Gtk.RevealerTransitionType.CROSSFADE
        };
        revealer.add (overlay);

        var label = new Gtk.Grid ();

        default_height = 0;
        default_width = 332;
        resizable = false;
        type_hint = Gdk.WindowTypeHint.NOTIFICATION;
        add (revealer);
        get_style_context ().add_class ("notification");
        set_titlebar (label);
        set_accept_focus (false);

        close_button.clicked.connect (() => {
            closed (Notify.Server.CloseReason.DISMISSED);
            dismiss ();
        });

        enter_notify_event.connect (() => {
            close_revealer.reveal_child = true;
            stop_timeout ();
            return Gdk.EVENT_PROPAGATE;
        });

        leave_notify_event.connect ((event) => {
            if (event.detail == Gdk.NotifyType.INFERIOR) {
                return Gdk.EVENT_STOP;
            }
            close_revealer.reveal_child = false;
            return Gdk.EVENT_PROPAGATE;
        });
    }

    protected void stop_timeout () {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
            timeout_id = 0;
        }
    }

    protected void start_timeout (uint timeout) {
        if (timeout_id != 0) {
            Source.remove (timeout_id);
        }

        timeout_id = GLib.Timeout.add (timeout, () => {
            timeout_id = 0;
            closed (Notify.Server.CloseReason.EXPIRED);
            dismiss ();
            return false;
        });
    }

    public void dismiss () {
        revealer.reveal_child = false;
        GLib.Timeout.add (revealer.transition_duration, () => {
            destroy ();
            return false;
        });
    }
}
