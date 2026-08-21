# frozen_string_literal: true

# The Solid Queue dashboard at /admin/jobs.
#
# Access is the same `admin` flag every other admin screen uses, so inheriting
# from Admin::BaseController is what gates it — and http_basic_auth, which the
# engine turns on by default, has to be switched off or it would ask for a
# second, separate password on top of that. The engine sets its own layout, so
# Admin::BaseController's `layout "admin"` does not apply here.
MissionControl::Jobs.base_controller_class = "Admin::BaseController"
MissionControl::Jobs.http_basic_auth_enabled = false
