#########################
# etcd cluster instances
#########################
# Delete the below comments to activate etcd.
resource "aws_instance" "etcd" {
    count = "${var.number_of_etcd}"
    ami = "${lookup(var.amis, var.region)}"
    instance_type = "${var.etcd_instance_type}"

    iam_instance_profile = "${aws_iam_instance_profile.kubernetes.id}"
    user_data = "${data.template_file.etcd-userdata.rendered}"

    subnet_id = "${aws_subnet.kubernetes.id}"
    private_ip = "${cidrhost(var.vpc_cidr, 10 + count.index)}"
    associate_public_ip_address = true # Instances have public, dynamic IP

    availability_zone = "${var.zone}"
    vpc_security_group_ids = ["${aws_security_group.kubernetes.id}"]
    key_name = "${var.default_keypair_name}"
    tags = "${merge(
    local.common_tags,
      map(
        "Owner", "${var.owner}",
        "Name", "etcd-${count.index}"
      )
    )}"
}
