show_tripod_mount=false;
show_bottom_platform=false;
show_top_platform=true;
show_lidar_mount=true;

// Extra width for mount: 1mm
mount_width = 1;
mount_offset = 1;
$fn=60;

module screw_mount_cylinder(h, d, fw=mount_width) {
    cylinder(h=h+fw, r=d/2 + mount_width);
}

module screw_mount(h, d, fw=mount_width) {
    difference() {
        screw_mount_cylinder(h,d,fw);
        translate([0,0,fw])
            cylinder(h=h, r=d/2);
    }
}

// quarter inch screw mount
module tripod_mount(w,screw_distance,screw_height,screw_socket_size=/*M3*/5) {
    union() {
        rotate([180,0,0])
        translate([screw_distance/2,screw_distance/2,-screw_height-mount_width])
            screw_mount(screw_height,screw_socket_size);
        rotate([180,0,0])
        translate([-screw_distance/2,screw_distance/2,-screw_height-mount_width])
            screw_mount(screw_height,screw_socket_size);
        rotate([180,0,0])
        translate([screw_distance/2,-screw_distance/2,-screw_height-mount_width])
            screw_mount(screw_height,screw_socket_size);
        rotate([180,0,0])
        translate([-screw_distance/2,-screw_distance/2,-screw_height-mount_width])
            screw_mount(screw_height,screw_socket_size);
        translate([0,0,1.3])
            screw_mount(12.7, 8);
        difference() {
            cylinder(h=15,r1=w,r2=w*0.50);
            translate([0,0,1.3])
                screw_mount_cylinder(12.7, 8-mount_width);
            translate([screw_distance/2,screw_distance/2,0])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width*2);
            translate([-screw_distance/2,screw_distance/2,0])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width*2);
            translate([screw_distance/2,-screw_distance/2,0])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width*2);
            translate([-screw_distance/2,-screw_distance/2,0])
                screw_mount_cylinder(screw_height,screw_socket_size-mount_width*2);
        }
    }
}

module mount_plattform(w,screw_offset,screw_distance,screw_size=/*M3*/3.5) {
    union() {
        if (screw_offset>0) {
            translate([(screw_distance/2),(screw_distance/2),0])
                screw_mount(screw_offset,screw_size,0);
            translate([-(screw_distance/2),(screw_distance/2),0])
                screw_mount(screw_offset,screw_size,0);
            translate([(screw_distance/2),-(screw_distance/2),0])
                screw_mount(screw_offset,screw_size,0);
            translate([-(screw_distance/2),-(screw_distance/2),0])
                screw_mount(screw_offset,screw_size,0);
        }
        difference() {
            translate([0,0,-1.5])
                minkowski() {
                    cube([w-8,w-8,1], true);
                    cylinder(1,r=4);
                }
            translate([(screw_distance/2),(screw_distance/2),-3])
                screw_mount_cylinder(screw_offset+3,screw_size-mount_width*2);
            translate([-(screw_distance/2),(screw_distance/2),-3])
                screw_mount_cylinder(screw_offset+3,screw_size-mount_width*2);
            translate([(screw_distance/2),-(screw_distance/2),-3])
                screw_mount_cylinder(screw_offset+3,screw_size-mount_width*2);
            translate([-(screw_distance/2),-(screw_distance/2),-3])
                screw_mount_cylinder(screw_offset+3,screw_size-mount_width*2);
        }
    }
}


module servo_mount(w,h,screw_distance,screw_height,screw_socket_size=/*M2*/3.2) {
    screw_offset=h-1;
    top_widht=screw_distance/2+screw_socket_size/2+mount_width*2;
    union() {
        translate([(screw_distance/2),0,screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([-(screw_distance/2),0,screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([0,(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([0,-(screw_distance/2),screw_offset])
            screw_mount(screw_height, screw_socket_size);
        difference() {
            cylinder(h, r1=w/2,r2=top_widht);
            translate([(screw_distance/2),0,screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([-(screw_distance/2),0,screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([0,(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([0,-(screw_distance/2),screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
        }
    }
}

module servo_frame(w,l,h,hw1,hw2,screw_position,screw_distance,screw_offset=2,screw_height=4,screw_socket_size=/*M2*/3.2) {
    union() {
        translate([l/2+screw_position,(screw_distance/2),h-screw_height-mount_width+screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([l/2+screw_position,-(screw_distance/2),h-screw_height-mount_width+screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([-l/2-screw_position,(screw_distance/2),h-screw_height-mount_width+screw_offset])
            screw_mount(screw_height, screw_socket_size);
        translate([-l/2-screw_position,-(screw_distance/2),h-screw_height-mount_width+screw_offset])
            screw_mount(screw_height, screw_socket_size);
        difference() {
            translate([0,0,(h-1-screw_offset)/2-1])
                // unline the other plattform, be at least as thick as screws to ensure it prints a good floor
                minkowski() {
                    cube([l*1.25,w,h-1-screw_offset+2],center=true);
                    cylinder(1,r=4);
                }
            translate([-10,0,0])
                cylinder(h=h-screw_offset,r1=hw1,r2=hw2);
            translate([-10,0,-2])
                cylinder(h=2,r=hw1);
            translate([0,0,h/2-screw_offset])
                cube([l,w+8,h],center=true);
            translate([l/2+screw_position,(screw_distance/2),h-screw_height-mount_width+screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([l/2+screw_position,-(screw_distance/2),h-screw_height-mount_width+screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([-l/2-screw_position,(screw_distance/2),h-screw_height-mount_width+screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
            translate([-l/2-screw_position,-(screw_distance/2),h-screw_height-mount_width+screw_offset])
                screw_mount_cylinder(screw_height, screw_socket_size-mount_width);
        }
    }
}

module measurement_ring(w,h,screw_distance,screw_socket_size=/*M3*/3.7) {
    difference() {
        union() {
            color("white")
            cylinder(h=h,r=w/2);
            color("black")
            for (tick=[0:1:180]) {
                rotate(tick,[0,0,1])
                    translate([0,(w/2)-2,2.2])
                    if (tick % 10 == 0) {
                        translate([0,-1,0])
                            cube([0.4,6,0.4], center=true);
                    } else {
                        cube([0.4,4,0.4], center=true);
                    }
            }
        }
        translate([w/4,0,1])
            cube([w/2,w,h*2],center=true);

        // copied from mount_platform above
        translate([-(screw_distance/2),(screw_distance/2),-1])
            screw_mount_cylinder(6,4);
        translate([-(screw_distance/2),-(screw_distance/2),-1])
            screw_mount_cylinder(6,4);
    }
}

module lidar_mount(foot_distance,offset,bolt_length,thickness=3,center_offset=10,bolt_size=6,bolt_socket_size=/*M5*/7,screw_distance_h=70,screw_distance_w1=56,screw_distance_w2=40,screw_size=/*M2.5*/2.7,screw_head_size=3.5) {
    foot_width = bolt_socket_size+mount_width*2;
    union() {
        s2_offset = (screw_distance_w1-screw_distance_w2) / 2;
        rotate([90,0,0]) {
            translate([-foot_distance/2,bolt_socket_size/2+mount_width+3,-bolt_length-mount_offset])
                screw_mount(bolt_length,bolt_socket_size);
            translate([foot_distance/2,bolt_socket_size/2+mount_width+3,-bolt_length-mount_offset])
                screw_mount(bolt_length,bolt_socket_size);
        }
        difference() {
            minkowski() {
                linear_extrude(thickness-1)
                polygon([
                        [-(foot_distance+foot_width)/2,offset/2],
                        [-screw_distance_h/2-5+center_offset,offset],
                        [-screw_distance_h/2-5+center_offset,offset+screw_distance_w1+5],
                        [-bolt_size-3,offset+screw_distance_w1+30],
                        [bolt_size+3,offset+screw_distance_w1+30],
                        [screw_distance_h/2+5+center_offset,offset+screw_distance_w2+5+s2_offset],
                        [screw_distance_h/2+5+center_offset,offset+s2_offset],
                        [(foot_distance+foot_width)/2,offset/2]
                        ], [[0,1,2,3,4,5,6,7]]);
                cylinder(1,r=4);
            }
            translate([-screw_distance_h/2+center_offset,offset,0]) {
                cylinder(h=thickness,r=screw_size/2);
                cylinder(h=thickness-3,r=screw_head_size/2);
            }
            translate([screw_distance_h/2+center_offset,offset+s2_offset,0]) {
                cylinder(h=thickness,r=screw_size/2);
                cylinder(h=thickness-3,r=screw_head_size/2);
            }
            translate([-screw_distance_h/2+center_offset,offset+screw_distance_w1,0]) {
                cylinder(h=thickness,r=screw_size/2);
                cylinder(h=thickness-3,r=screw_head_size/2);
            }
            translate([screw_distance_h/2+center_offset,offset+screw_distance_w2+s2_offset,0]) {
                cylinder(h=thickness,r=screw_size/2);
                cylinder(h=thickness-3,r=screw_head_size/2);
            }
            translate([-bolt_size,offset+screw_distance_w1+36-foot_width]) 
                cylinder(thickness, r=bolt_size/2);
            translate([bolt_size,offset+screw_distance_w1+36-foot_width]) 
                cylinder(thickness, r=bolt_size/2);
        }
        difference() {
            minkowski() {
                union() {
                    rotate([0,-90,0])
                    translate([1,1,(foot_distance-foot_width)/2])
                    linear_extrude(foot_width)
                    polygon([[0,0],
                                [15,0],
                                [0,offset]], [[0,1,2]]);
                    rotate([0,-90,0])
                    translate([1,1,-(foot_distance+foot_width)/2])
                    linear_extrude(foot_width)
                    polygon([[0,0],
                                [15,0],
                                [0,offset]], [[0,1,2]]);
                }
                rotate([90,0,0])
                cylinder(1, r=1);
            }
            rotate([90,0,0]) {
                translate([-foot_distance/2,bolt_socket_size/2+mount_width+3,-bolt_length-mount_offset])
                    screw_mount_cylinder(bolt_length,bolt_socket_size-mount_width);
                translate([foot_distance/2,bolt_socket_size/2+mount_width+3,-bolt_length-mount_offset])
                    screw_mount_cylinder(bolt_length,bolt_socket_size-mount_width);
            }
        }
    }
}

if (show_bottom_platform) {
translate([0,0,-8])
// Bottom mount platform
difference() {
    union() {
        mount_plattform(75, 2, 58);
        // Mount platform for servo motor -> Directly mounted to bottom plattform
        servo_mount(w=32, h=4, screw_distance=15, screw_height=4);
        //bevel_gear(0.75, 40, 45, 4, 0, 20, 25);
        translate([0,0,-2])
            measurement_ring(120,2,58);
    }
    translate([15,15,-4])
        screw_mount_cylinder(h=4, d=3-mount_width*2);
    translate([-15,15,-4])
        screw_mount_cylinder(h=4, d=3-mount_width*2);
    translate([15,-15,-4])
        screw_mount_cylinder(h=4, d=3-mount_width*2);
    translate([-15,-15,-4])
        screw_mount_cylinder(h=4, d=3-mount_width*2);
}
}

if (show_tripod_mount) {
    // Tripod mount to screw on
    // Screw socket for 1/4 mount
    rotate([-180,0,0])
        translate([0,0,10])
            tripod_mount(30,30,4);
}

if (show_top_platform) {
    translate([0,0,6])
    // Top platform for servo and lidar
    union() {
        difference() {
            mount_plattform(75, 0, 58);
            translate([0,0,-3])
            cylinder(3, r=11);
        }
        translate([10,0,0])
            servo_frame(w=20, l=40, h=8, hw1=11,hw2=9.5, screw_position=4.5, screw_distance=10);
        translate([-37,0,-2])
        linear_extrude(2)
        polygon(points = [[0,-4],[0,4],[-21,0]], paths = [[0,1,2]]);

        translate([-20,0,0]) 
        difference() {
            translate([0,43,-1.5])
                minkowski() {
                    cube([8,10,1], true);
                    cylinder(1,r=4);
                }
            translate([0,45+3-7/2-mount_width,-3])
                cylinder(5, r=2.8);
        }
        translate([20,0,0]) 
        difference() {
            translate([0,43,-1.5])
                minkowski() {
                    cube([8,10,1], true);
                    cylinder(1,r=4);
                }
            translate([0,45+3-7/2-mount_width,-3])
                cylinder(5, r=2.8);
        }
        rotate([0,0,180]) 
        difference() {
            translate([0,40,-1.5])
                minkowski() {
                    cube([15,5,1], true);
                    cylinder(1,r=4);
                }
            translate([-6,45-7/2-mount_width,-3])
                cylinder(5, r=2.8);
            translate([6,45-7/2-mount_width,-3])
                cylinder(5, r=2.8);
        }
    }
}

if (show_lidar_mount) {
    // Lidar Mount
    translate([0,45+6,6])
        rotate([90,0,0])
            lidar_mount(40, 60, 10,6);
}
