namespace G4 {

    public class MusicList : Adw.Bin {
        private bool _compact_list = false;
        private ListStore _data_store = new ListStore (typeof (Music));
        private Gtk.FilterListModel? _filter_model = null;
        private bool _grid_mode = false;
        private int _image_size = 96;
        private Gtk.GridView? _grid_view = null;
        private Gtk.ListView? _list_view = null;
        private Gtk.ListBase _list_base;
        private Gtk.ScrolledWindow _scroll_view = new Gtk.ScrolledWindow ();
        private Thumbnailer _thmbnailer;
        private double _row_height = 0;
        private double _scroll_range = 0;

        public signal void item_activated (uint position, Object? obj);
        public signal void item_created (Gtk.ListItem item);
        public signal void item_binded (Gtk.ListItem item);

        public MusicList (Application app, bool grid = false) {
            this.child = _scroll_view;
            _grid_mode = grid;
            _image_size = grid ? Thumbnailer.GRID_SIZE : Thumbnailer.ICON_SIZE;
            _thmbnailer = app.thumbnailer;

            if (grid) {
                var grid_view = new Gtk.GridView (null, null);
                grid_view.enable_rubberband = false;
                grid_view.single_click_activate = true;
                grid_view.activate.connect ((position) => item_activated (position, _grid_view?.get_model ()?.get_item (position)));
                _grid_view = grid_view;
                _list_base = grid_view;
            } else {
                var list_view = new Gtk.ListView (null, null);
                list_view.enable_rubberband = false;
                list_view.single_click_activate = true;
                list_view.activate.connect ((position) => item_activated (position, _list_view?.get_model ()?.get_item (position)));
                _list_view = list_view;
                _list_base = list_view;
            }

            _list_base.add_css_class ("navigation-sidebar");
            _scroll_view.child = _list_base;
            _scroll_view.hscrollbar_policy = Gtk.PolicyType.NEVER;
            _scroll_view.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
            _scroll_view.vexpand = true;
            _scroll_view.vadjustment.changed.connect (on_vadjustment_changed);
        }

        public bool compact_list {
            get {
                return _compact_list;
            }
            set {
                _compact_list = value;
                create_factory ();
            }
        }

        public ListStore data_store {
            get {
                return _data_store;
            }
        }

        public Gtk.FilterListModel? filter_model {
            get {
                return _filter_model;
            }
            set {
                if (value != null)
                    ((!)value).model = _data_store;
                _filter_model = value;
                var selection = new Gtk.NoSelection (value);
                if (_grid_mode)
                    _grid_view?.set_model (selection);
                else
                    _list_view?.set_model (selection);
            }
        }

        public uint visible_count {
            get {
                var model = _grid_mode ? _grid_view?.get_model () : _list_view?.get_model ();
                return model?.get_n_items () ?? 0;
            }
        }

        public void create_factory () {
            var factory = new Gtk.SignalListItemFactory ();
            factory.setup.connect (on_create_item);
            factory.bind.connect (on_bind_item);
            factory.unbind.connect (on_unbind_item);
            if (_grid_mode)
                _grid_view?.set_factory (factory);
            else
                _list_view?.set_factory (factory);
        }

        private Adw.Animation? _scroll_animation = null;

        public void scroll_to_item (int index) {
            var adj = _scroll_view.vadjustment;
            var list_height = _list_base.get_height ();
            if (_row_height > 0 && adj.upper - adj.lower > list_height) {
                var from = adj.value;
                var max_to = double.max ((index + 1) * _row_height - list_height, 0);
                var min_to = double.max (index * _row_height, 0);
                var scroll_to =  from < max_to ? max_to : (from > min_to ? min_to : from);
                var diff = (scroll_to - from).abs ();
                if (diff > list_height) {
                    _scroll_animation?.pause ();
                    adj.value = min_to;
                } else if (diff > 0) {
                    //  Scroll smoothly
                    var target = new Adw.CallbackAnimationTarget (adj.set_value);
                    _scroll_animation?.pause ();
                    _scroll_animation = new Adw.TimedAnimation (_scroll_view, from, scroll_to, 500, target);
                    _scroll_animation?.play ();
                } 
            } else if (visible_count > 0) {
#if GTK_4_10
                _list_base.activate_action_variant ("list.scroll-to-item", new Variant.uint32 (index));
#else
                //  Delay scroll if items not size_allocated, to ensure items visible in GNOME 42
                run_idle_once (() => scroll_to_item (index));
#endif
            }
        }

        private void on_create_item (Gtk.ListItem item) {
            if (_grid_mode)
                item.child = new MusicCell ();
            else
                item.child = new MusicEntry (_compact_list);
            item_created (item);
            _row_height = item.child.height_request + 2;
        }

        private void on_bind_item (Gtk.ListItem item) {
            var entry = (MusicWidget) item.child;
            var music = (Music) item.item;
            item_binded (item);

            var paintable = _thmbnailer.find (music, _image_size);
            if (paintable != null) {
                entry.paintable = paintable;
            } else {
                entry.first_draw_handler = entry.cover.first_draw.connect (() => {
                    entry.disconnect_first_draw ();
                    _thmbnailer.load_async.begin (music, _image_size, (obj, res) => {
                        var paintable2 = _thmbnailer.load_async.end (res);
                        if (music == (Music) item.item) {
                            entry.paintable = paintable2;
                        }
                    });
                });
            }
        }

        private void on_unbind_item (Gtk.ListItem item) {
            var entry = (MusicWidget) item.child;
            entry.disconnect_first_draw ();
            entry.paintable = null;
        }

        private void on_vadjustment_changed () {
            var adj = _scroll_view.vadjustment;
            var range = adj.upper - adj.lower;
            var count = visible_count;
            if (count > 0 && _scroll_range != range && range > _list_base.get_height ()) {
                _row_height = range / count;
                _scroll_range = range;
            }
        }
    }
}