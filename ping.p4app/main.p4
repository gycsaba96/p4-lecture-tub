#include <core.p4>
#include <v1model.p4>

/***** Header definitions *****/

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> src;
    bit<32> dst;
}

header icmp_t{
    bit<8> icmp_type;
    bit<8> code;
    bit<16> csum;
}

/***** Struct representing the possible headers *****/

struct headers {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    icmp_t       icmp;
}

/***** User defined metadata structure *****/

struct metadata {
}

/***** Parser *****/

parser MyParser(packet_in pkt,
                out headers hdr,
                inout metadata meta,
                inout standard_metadata_t standard_metadata) {

    state start {
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            16w0x800: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol){
            1  : parse_icmp;
            default: accept;
        }
    }

    state parse_icmp {
        pkt.extract(hdr.icmp);
        transition accept;
    }

}


/***** (Unused) control block for checksum verification *****/

control MyVerifyChecksum(inout headers hdr,
                         inout metadata meta) {
    apply { }
}


/***** Ingress pipeline *****/

control MyIngress(inout headers hdr,
                  inout metadata meta,
                  inout standard_metadata_t standard_metadata) {
    
    action set_eport(bit<9> port){
        standard_metadata.egress_spec = port;
    }

    action drop_packet(){
        mark_to_drop(standard_metadata);
    }

    table portfwd{
        key = {
            standard_metadata.ingress_port: exact;
        }
        actions = {
            set_eport;
            drop_packet;
        }
        const default_action = drop_packet;
        const entries = {
                1 : set_eport(2);
                2 : set_eport(1);
        }
    }

    apply {
        
        if (hdr.icmp.isValid() && hdr.icmp.icmp_type==8){
            // *** transform ping to pong
            hdr.icmp.icmp_type = 0;
            hdr.icmp.csum = 0;

            // *** send it back
            
            // set outgoing port
            standard_metadata.egress_spec = standard_metadata.ingress_port;
            
            // swap MAC addresses
            bit<48> tmp1 = hdr.ethernet.srcAddr;
            hdr.ethernet.srcAddr = hdr.ethernet.dstAddr;
            hdr.ethernet.dstAddr = tmp1;
            
            // swap IP addresses
            bit<32> tmp2 = hdr.ipv4.src;
            hdr.ipv4.src = hdr.ipv4.dst;
            hdr.ipv4.dst = tmp2;
        }
        else{
            // *** static forwarding based on the in-port
            portfwd.apply();
        }

    }
}

/***** (Unused) egress block *****/

control MyEgress(inout headers hdr,
                 inout metadata meta,
                 inout standard_metadata_t standard_metadata) {
    apply { }
}


/***** Block for fixing checksums *****/

control MyComputeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(
                hdr.ipv4.isValid(),
                { 
                hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv,
                hdr.ipv4.totalLen, hdr.ipv4.identification,
                hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl,
                hdr.ipv4.protocol, hdr.ipv4.src, hdr.ipv4.dst 
                },
                hdr.ipv4.hdrChecksum,
                HashAlgorithm.csum16
            );
    }
}

/***** Deparser *****/

control MyDeparser(packet_out pkt, in headers hdr) {
    apply {
        pkt.emit(hdr);
    }
}

/***** Let's put together everything *****/

V1Switch(
MyParser(),
MyVerifyChecksum(),
MyIngress(),
MyEgress(),
MyComputeChecksum(),
MyDeparser()
) main;
