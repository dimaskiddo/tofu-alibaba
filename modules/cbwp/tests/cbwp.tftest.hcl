mock_provider "alicloud" {}

variables {
  name      = "cbwp-1-c1-example-stage"
  bandwidth = 20
  tags      = { env = "stage" }
}

run "defaults" {
  command = plan

  assert {
    condition = (
      alicloud_common_bandwidth_package.this.bandwidth_package_name == "cbwp-1-c1-example-stage" &&
      alicloud_common_bandwidth_package.this.bandwidth == "20" &&
      alicloud_common_bandwidth_package.this.internet_charge_type == "PayByBandwidth" &&
      alicloud_common_bandwidth_package.this.isp == "BGP" &&
      alicloud_common_bandwidth_package.this.deletion_protection == false
    )
    error_message = "defaults must be PayByBandwidth, BGP, deletion protection off"
  }

  assert {
    condition     = alicloud_common_bandwidth_package.this.tags["env"] == "stage"
    error_message = "tags must reach the package"
  }

  assert {
    condition     = length(alicloud_common_bandwidth_package_attachment.this) == 0 && length(alicloud_alb_load_balancer_common_bandwidth_package_attachment.this) == 0
    error_message = "no attachments without eip_ids / alb_ids"
  }
}

run "attachments" {
  command = plan
  variables {
    eip_ids = { eip-a = "eip-1", eip-b = "eip-2" }
    alb_ids = { alb-a = "alb-1" }
  }

  assert {
    condition     = length(alicloud_common_bandwidth_package_attachment.this) == 2 && length(alicloud_alb_load_balancer_common_bandwidth_package_attachment.this) == 1
    error_message = "one attachment per eip_ids / alb_ids entry"
  }

  assert {
    condition     = alicloud_common_bandwidth_package_attachment.this["eip-a"].instance_id == "eip-1" && alicloud_alb_load_balancer_common_bandwidth_package_attachment.this["alb-a"].load_balancer_id == "alb-1"
    error_message = "attachments must carry the given IDs"
  }
}

run "traffic_charge_type" {
  command = plan
  variables { internet_charge_type = "PayByTraffic" }

  assert {
    condition     = alicloud_common_bandwidth_package.this.internet_charge_type == "PayByTraffic"
    error_message = "PayByTraffic must pass through"
  }
}

run "bad_name_rejected" {
  command = plan
  variables { name = "Cbwp_1" }
  expect_failures = [var.name]
}

run "bandwidth_zero_rejected" {
  command = plan
  variables { bandwidth = 0 }
  expect_failures = [var.bandwidth]
}

run "bandwidth_too_big_rejected" {
  command = plan
  variables { bandwidth = 1001 }
  expect_failures = [var.bandwidth]
}

run "bandwidth_fraction_rejected" {
  command = plan
  variables { bandwidth = 1.5 }
  expect_failures = [var.bandwidth]
}

run "payby95_rejected" {
  command = plan
  variables { internet_charge_type = "PayBy95" }
  expect_failures = [var.internet_charge_type]
}

run "bad_isp_rejected" {
  command = plan
  variables { isp = "ChinaTelecom" }
  expect_failures = [var.isp]
}

run "short_description_rejected" {
  command = plan
  variables { description = "x" }
  expect_failures = [var.description]
}

run "bad_eip_id_rejected" {
  command = plan
  variables { eip_ids = { eip-a = "i-1" } }
  expect_failures = [var.eip_ids]
}

run "too_many_eips_rejected" {
  command = plan
  variables {
    eip_ids = {
      eip-0   = "eip-0"
      eip-1   = "eip-1"
      eip-2   = "eip-2"
      eip-3   = "eip-3"
      eip-4   = "eip-4"
      eip-5   = "eip-5"
      eip-6   = "eip-6"
      eip-7   = "eip-7"
      eip-8   = "eip-8"
      eip-9   = "eip-9"
      eip-10  = "eip-10"
      eip-11  = "eip-11"
      eip-12  = "eip-12"
      eip-13  = "eip-13"
      eip-14  = "eip-14"
      eip-15  = "eip-15"
      eip-16  = "eip-16"
      eip-17  = "eip-17"
      eip-18  = "eip-18"
      eip-19  = "eip-19"
      eip-20  = "eip-20"
      eip-21  = "eip-21"
      eip-22  = "eip-22"
      eip-23  = "eip-23"
      eip-24  = "eip-24"
      eip-25  = "eip-25"
      eip-26  = "eip-26"
      eip-27  = "eip-27"
      eip-28  = "eip-28"
      eip-29  = "eip-29"
      eip-30  = "eip-30"
      eip-31  = "eip-31"
      eip-32  = "eip-32"
      eip-33  = "eip-33"
      eip-34  = "eip-34"
      eip-35  = "eip-35"
      eip-36  = "eip-36"
      eip-37  = "eip-37"
      eip-38  = "eip-38"
      eip-39  = "eip-39"
      eip-40  = "eip-40"
      eip-41  = "eip-41"
      eip-42  = "eip-42"
      eip-43  = "eip-43"
      eip-44  = "eip-44"
      eip-45  = "eip-45"
      eip-46  = "eip-46"
      eip-47  = "eip-47"
      eip-48  = "eip-48"
      eip-49  = "eip-49"
      eip-50  = "eip-50"
      eip-51  = "eip-51"
      eip-52  = "eip-52"
      eip-53  = "eip-53"
      eip-54  = "eip-54"
      eip-55  = "eip-55"
      eip-56  = "eip-56"
      eip-57  = "eip-57"
      eip-58  = "eip-58"
      eip-59  = "eip-59"
      eip-60  = "eip-60"
      eip-61  = "eip-61"
      eip-62  = "eip-62"
      eip-63  = "eip-63"
      eip-64  = "eip-64"
      eip-65  = "eip-65"
      eip-66  = "eip-66"
      eip-67  = "eip-67"
      eip-68  = "eip-68"
      eip-69  = "eip-69"
      eip-70  = "eip-70"
      eip-71  = "eip-71"
      eip-72  = "eip-72"
      eip-73  = "eip-73"
      eip-74  = "eip-74"
      eip-75  = "eip-75"
      eip-76  = "eip-76"
      eip-77  = "eip-77"
      eip-78  = "eip-78"
      eip-79  = "eip-79"
      eip-80  = "eip-80"
      eip-81  = "eip-81"
      eip-82  = "eip-82"
      eip-83  = "eip-83"
      eip-84  = "eip-84"
      eip-85  = "eip-85"
      eip-86  = "eip-86"
      eip-87  = "eip-87"
      eip-88  = "eip-88"
      eip-89  = "eip-89"
      eip-90  = "eip-90"
      eip-91  = "eip-91"
      eip-92  = "eip-92"
      eip-93  = "eip-93"
      eip-94  = "eip-94"
      eip-95  = "eip-95"
      eip-96  = "eip-96"
      eip-97  = "eip-97"
      eip-98  = "eip-98"
      eip-99  = "eip-99"
      eip-100 = "eip-100"
    }
  }
  expect_failures = [var.eip_ids]
}

run "bad_alb_id_rejected" {
  command = plan
  variables { alb_ids = { alb-a = "lb-1" } }
  expect_failures = [var.alb_ids]
}

run "empty_tags_rejected" {
  command = plan
  variables { tags = {} }
  expect_failures = [var.tags]
}

run "empty_tag_value_rejected" {
  command = plan
  variables { tags = { env = "" } }
  expect_failures = [var.tags]
}
