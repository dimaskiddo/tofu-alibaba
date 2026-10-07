output "peer_connection_id" {
  description = "VPC peering connection ID, usable as a VpcPeer route next hop."
  value       = alicloud_vpc_peer_connection.this.id
}

output "route_entry_ids" {
  description = "Peer route entry IDs by side; only the routes that were requested."
  value = merge(
    { for e in alicloud_route_entry.requester : "requester" => e.id },
    { for e in alicloud_route_entry.accepter : "accepter" => e.id },
  )
}

output "tags" {
  description = "Tags applied to the peering connection."
  value       = alicloud_vpc_peer_connection.this.tags
}
