/*
 *  Copyright (C) 2011-2015 Granite Developers (https://launchpad.net/granite)
 *
 *  This program or library is free software; you can redistribute it
 *  and/or modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General
 *  Public License along with this library; if not, write to the
 *  Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 *  Boston, MA 02110-1301 USA.
 *
 *  Authored by: Corentin Noël <corentin@elementary.io>
 */
public class Granite.Widgets.StorageBar : Gtk.Box {
    public enum ItemDescription {
        OTHER,
        AUDIO,
        VIDEO,
        PHOTO,
        APP;

        public static string? get_class (ItemDescription description) {
            switch (description) {
                case ItemDescription.AUDIO:
                    return "audio";
                case ItemDescription.VIDEO:
                    return "video";
                case ItemDescription.PHOTO:
                    return "photo";
                case ItemDescription.APP:
                    return "app";
                default:
                    return null;
            }
        }

        public static string get_name (ItemDescription description) {
            switch (description) {
                case ItemDescription.AUDIO:
                    return _("Audio");
                case ItemDescription.VIDEO:
                    return _("Videos");
                case ItemDescription.PHOTO:
                    return _("Photos");
                case ItemDescription.APP:
                    return _("Apps");
                default:
                    return _("Others");
            }
        }
    }

    private uint64 _storage = 0;
    public uint64 storage {
        get {
            return _storage;
        }
        set {
            _storage = value;
            resize_children ();
            update_size_description ();
        }
    }

    public int inner_margin_sides {
        get {
            return fillblock_box.margin_start;
        }
        set {
            fillblock_box.margin_end = fillblock_box.margin_start = value;
        }
    }

    private Gtk.Label description_label;
    private GLib.HashTable<int, FillBlock> blocks;
    private int index = 0;
    private Gtk.Box fillblock_box;
    private Gtk.Box legend_box;

    public StorageBar (uint64 storage) {
        Object (storage: storage);
    }

    construct {
        orientation = Gtk.Orientation.VERTICAL;
        description_label = new Gtk.Label (null);
        description_label.hexpand = true;
        description_label.margin_top = 6;
        get_style_context ().add_class ("storage-bar");
        blocks = new GLib.HashTable<int, FillBlock> (null, null);
        fillblock_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        fillblock_box.get_style_context ().add_class ("fill-block");
        fillblock_box.get_style_context ().add_class ("empty-block");
        fillblock_box.hexpand = true;
        inner_margin_sides = 12;
        legend_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        legend_box.expand = true;
        var legend_center_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        legend_center_box.set_center_widget (legend_box);
        var legend_scrolled = new Gtk.ScrolledWindow (null, null);
        legend_scrolled.vscrollbar_policy = Gtk.PolicyType.NEVER;
        legend_scrolled.hexpand = true;
        legend_scrolled.add (legend_center_box);
        var grid = new Gtk.Grid ();
        grid.attach (legend_scrolled, 0, 0, 1, 1);
        grid.attach (fillblock_box, 0, 1, 1, 1);
        grid.attach (description_label, 0, 2, 1, 1);
        set_center_widget (grid);

        fillblock_box.size_allocate.connect ((allocation) => {
            // lost_size is here because we use truncation so that it is possible for a full device to have a filed bar.
            double lost_size = 0;
            int current_x = allocation.x;
            for (int i = 0; i < blocks.length; i++) {
                weak FillBlock block = blocks.get (i);
                if (block == null || block.visible == false)
                    continue;

                var new_allocation = Gtk.Allocation ();
                new_allocation.x = current_x;
                new_allocation.y = allocation.y;
                double width = (((double)allocation.width) * (double) block.size / (double) storage) + lost_size;
                lost_size -= GLib.Math.trunc (lost_size);
                new_allocation.width = (int) GLib.Math.trunc (width);
                new_allocation.height = allocation.height;
                block.size_allocate_with_baseline (new_allocation, block.get_allocated_baseline ());

                lost_size = width - new_allocation.width;
                current_x += new_allocation.width;
            }
        });

        create_default_blocks ();
    }

    private void create_default_blocks () {
        var seq = new Sequence<ItemDescription> ();
        seq.append (ItemDescription.OTHER);
        seq.append (ItemDescription.AUDIO);
        seq.append (ItemDescription.VIDEO);
        seq.append (ItemDescription.PHOTO);
        seq.append (ItemDescription.APP);
        seq.sort ((a, b) => {
            if (a == ItemDescription.OTHER)
                return 1;
            if (b == ItemDescription.OTHER)
                return -1;

            return ItemDescription.get_name (a).collate (ItemDescription.get_name (b));
        });

        seq.foreach ((description) => {
            var fill_block = new FillBlock (description, 0);
            fillblock_box.add (fill_block);
            legend_box.add (fill_block.legend_item);
            blocks.set (index, fill_block);
            index++;
        });
        update_size_description ();
    }

    private void update_size_description () {
        uint64 user_size = 0;
        foreach (weak FillBlock block in blocks.get_values ()) {
            if (block.visible == false)
                continue;
            user_size += block.size;
        }

        uint64 free = storage - user_size;
        description_label.label = _("%s free out of %s").printf (GLib.format_size (free), GLib.format_size (storage));
    }

    public void update_block_size (ItemDescription description, uint64 size) {
        foreach (weak FillBlock block in blocks.get_values ()) {
            if (block.description == description) {
                block.size = size;
                update_size_description ();
                return;
            }
        }
    }

    public class FillBlock : Gtk.Label {
        private uint64 _size = 0;
        public uint64 size {
            get {
                return _size;
            }
            set {
                _size = value;
                if (_size == 0) {
                    no_show_all = true;
                    visible = false;
                    legend_item.no_show_all = true;
                    legend_item.visible = false;
                } else {
                    no_show_all = false;
                    visible = true;
                    legend_item.no_show_all = false;
                    legend_item.visible = true;
                    size_label.label = GLib.format_size (_size);
                    queue_resize ();
                }
            }
        }

        public ItemDescription description { public get; construct set; }
        public Gtk.Grid legend_item { public get; private set; }
        private Gtk.Label name_label;
        private Gtk.Label size_label;
        private Gtk.Label legend_fill;

        public FillBlock (ItemDescription description, uint64 size) {
            Object (size: size, description: description);
            var clas = ItemDescription.get_class (description);
            if (clas != null) {
                get_style_context ().add_class (clas);
                legend_fill.get_style_context ().add_class (clas);
            }

            name_label.label = "<b>%s</b>".printf (GLib.Markup.escape_text (ItemDescription.get_name (description)));
        }

        construct {
            get_style_context ().add_class ("fill-block");
            legend_item = new Gtk.Grid ();
            legend_item.column_spacing = 6;
            name_label = new Gtk.Label (null);
            name_label.halign = Gtk.Align.START;
            name_label.use_markup = true;
            size_label = new Gtk.Label (null);
            size_label.halign = Gtk.Align.START;
            legend_fill = new Gtk.Label (null);
            legend_fill.get_style_context ().add_class ("fill-block");
            var legend_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            legend_box.set_center_widget (legend_fill);
            legend_item.attach (legend_box, 0, 0, 1, 2);
            legend_item.attach (name_label, 1, 0, 1, 1);
            legend_item.attach (size_label, 1, 1, 1, 1);
        }
    }
}
