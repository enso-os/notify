/*
* Copyright 2019-2020 elementary, Inc. (https://elementary.io)
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

public class Notify.Bubble : AbstractBubble {
    public signal void action_invoked (string action_key);

    public Notify.Notification notification { get; construct; }
    public uint32 id { get; construct; }

    public Bubble (Notify.Notification notification, string[] actions, uint32 id) {
        Object (
            notification: notification,
            id: id
        );
    }

    construct {
        var contents = new Contents (notification);

        content_area.add (contents);

        switch (notification.priority) {
            case GLib.NotificationPriority.HIGH:
            case GLib.NotificationPriority.URGENT:
                content_area.get_style_context ().add_class ("urgent");
                break;
            default:
                start_timeout (4000);
                break;
        }

        if (notification.app_info != null) {
            bool default_action = false;

            for (int i = 0; i < notification.actions.length; i += 2) {
                if (notification.actions[i] == "default") {
                    default_action = true;
                    break;
                }
            }

            button_press_event.connect ((event) => {
                if (default_action) {
                    launch_action ("default");
                } else {
                    try {
                        notification.app_info.launch (null, null);
                        dismiss ();
                    } catch (Error e) {
                        critical ("Unable to launch app: %s", e.message);
                    }
                }
                return Gdk.EVENT_STOP;
            });
        }

        leave_notify_event.connect (() => {
            if (notification.priority == GLib.NotificationPriority.HIGH || notification.priority == GLib.NotificationPriority.URGENT) {
                return Gdk.EVENT_PROPAGATE;
            }
            start_timeout (4000);
        });
    }

    private void launch_action (string action_key) {
        notification.app_info.launch_action (action_key, new GLib.AppLaunchContext ());
        action_invoked (action_key);
        dismiss ();
    }

    public void replace (Notify.Notification new_notification) {
        start_timeout (4000);

        var new_contents = new Contents (new_notification);
        new_contents.show_all ();

        content_area.add (new_contents);
        content_area.visible_child = new_contents;
    }

    private class Contents : Gtk.Grid {
        public Notify.Notification notification { get; construct; }

        public Contents (Notify.Notification notification) {
            Object (notification: notification);
        }

        construct {
            var app_image = new Gtk.Image ();
            app_image.icon_name = notification.app_icon;

            var image_overlay = new Gtk.Overlay ();
            image_overlay.valign = Gtk.Align.START;

            if (notification.image_path != null) {
                try {
                    var scale = get_style_context ().get_scale ();
                    var pixbuf = new Gdk.Pixbuf.from_file_at_size (notification.image_path, 48 * scale, 48 * scale);

                    var masked_image = new Notify.MaskedImage (pixbuf);

                    app_image.pixel_size = 24;
                    app_image.halign = app_image.valign = Gtk.Align.END;

                    image_overlay.add (masked_image);
                    image_overlay.add_overlay (app_image);
                } catch (Error e) {
                    critical ("Unable to mask image: %s", e.message);

                    app_image.pixel_size = 48;
                    image_overlay.add (app_image);
                }
            } else {
                app_image.pixel_size = 48;
                image_overlay.add (app_image);
            }

            var title_label = new Gtk.Label (notification.summary) {
                ellipsize = Pango.EllipsizeMode.END,
                max_width_chars = 33,
                valign = Gtk.Align.END,
                width_chars = 33,
                xalign = 0
            };
            title_label.get_style_context ().add_class ("title");

            var body_label = new Gtk.Label (notification.body) {
                ellipsize = Pango.EllipsizeMode.END,
                lines = 2,
                max_width_chars = 33,
                use_markup = true,
                valign = Gtk.Align.START,
                width_chars = 33,
                wrap = true,
                xalign = 0
            };

            if ("\n" in notification.body) {
                string[] lines = notification.body.split ("\n");
                string stripped_body = lines[0] + "\n";
                for (int i = 1; i < lines.length; i++) {
                    stripped_body += lines[i].strip () + "";
                }

                body_label.label = stripped_body.strip ();
                body_label.lines = 1;
            }

            column_spacing = 6;
            attach (image_overlay, 0, 0, 1, 2);
            attach (title_label, 1, 0);
            attach (body_label, 1, 1);
        }
    }
}
