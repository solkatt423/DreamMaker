/// DreamGame: fixed-step simulation, sticker inventory and prototype presentation.
function DreamGame() constructor {
    width=1366; play_height=576; level_width=4098; gravity=850; run_speed=100;
    // Recording pace: slow simulation together so spring/hook routes keep their shape.
    play_pace=0.8;
    step_up=32; step_down=40; small_gap=20; snap_range=24; foot_half=9;
    // Wider visual footprints for tall stickers, with a small visible-edge tolerance.
    ground_widths=[0.48,0.46,0.46,0.44,0.47,0.45,0.44,0.46];
    ground_y=405; start_right=480; goal_x=3978; goal_left=3740;
    camera_x=0; follow_x=width/3; grab_height=64; body_half=17; body_height=72;
    hook_radius=180; release_angle=degtorad(40);
    ink=make_color_rgb(233,227,211); muted=make_color_rgb(146,142,133); accent=make_color_rgb(203,174,119);
    colours=[make_color_rgb(159,196,165),make_color_rgb(169,180,221),make_color_rgb(225,171,127)];
    slots=[296,683,1070]; library_y=652; deck_w=244; deck_h=112; label_h=28; label_y=747; sizes=[[270,150],[150,150],[138,146]];
    assets=[[],[],[]]; counts=[8,5,3]; prefixes=["ground","hook","spring"]; all_sprites=[]; labels=[];
    font_title=font_add("Georgia",29,false,true,32,128);
    randomise(); seed=irandom(1000000); clock_time=0; accumulator=0; mx=0; my=0;
    load_art=function(_path) {
        var _spr=sprite_add(_path,1,false,false,0,0);
        if (_spr<0) { show_debug_message("Missing artwork: "+_path); return {sprite:-1,w:100,h:100,left:0,top:0}; }
        array_push(all_sprites,_spr);
        var _l=sprite_get_bbox_left(_spr), _t=sprite_get_bbox_top(_spr);
        return {sprite:_spr,left:_l,top:_t,w:max(1,sprite_get_bbox_right(_spr)-_l+1),h:max(1,sprite_get_bbox_bottom(_spr)-_t+1)};
    };
    for (var _k=0;_k<3;_k++) for (var _i=1;_i<=counts[_k];_i++) array_push(assets[_k],load_art("stickers/"+prefixes[_k]+string(_i)+".png"));
    destination=load_art("stickers/destination.png");
    obstacle_art=[];
    for(var i=1;i<=4;i++) array_push(obstacle_art,load_art("stickers/obstacle"+string(i)+".png"));
    // Positions are world coordinates. Decorative tips are outside these stable cores.
    make_obstacle=function(_variant,_x,_y,_maxw,_maxh) {
        var a=obstacle_art[_variant], scale=min(_maxw/a.w,_maxh/a.h);
        var w=a.w*scale, h=a.h*scale;
        return {variant:_variant,px:_x,py:_y,w:w,h:h,
                cx:_x,cy:_y+h*0.04,rx:w*0.30,ry:h*0.30};
    };
    reset_obstacles=function() {
        obstacles=[make_obstacle(0,900,425,130,168),
                   make_obstacle(1,1700,385,154,176),
                   make_obstacle(2,2500,205,240,170),
                   make_obstacle(3,3200,420,210,156)];
    };
    // Sweep a deliberately narrow three-part body through expanded ellipses.
    // Normalizing each segment also catches fast spring and swing travel.
    obstacle_contact=function(_x0,_y0,_x1,_y1) {
        var first=2, hit=-1;
        for(var i=0;i<array_length(obstacles);i++) {
            var o=obstacles[i], rx=o.rx+8, ry=o.ry+8;
            for(var part=0;part<3;part++) {
                var offset=12+part*21;
                var ax=(_x0-o.cx)/rx, ay=(_y0-offset-o.cy)/ry;
                var dx=(_x1-_x0)/rx, dy=(_y1-_y0)/ry;
                var aa=dx*dx+dy*dy, bb=2*(ax*dx+ay*dy), cc=ax*ax+ay*ay-1;
                var t=2;
                if(cc<=0) t=0;
                else if(aa>0.0000001) {
                    var disc=bb*bb-4*aa*cc;
                    if(disc>=0) {
                        var entry=(-bb-sqrt(disc))/(2*aa);
                        if(entry>=0 && entry<=1) t=entry;
                    }
                }
                if(t<first) { first=t; hit=i; }
            }
        }
        return {index:hit,time:first};
    };
    check_obstacles=function(_oldx,_oldy) {
        if(mode!="playing") return false;
        var p=player, contact=obstacle_contact(_oldx,_oldy,p.px,p.py);
        if(contact.index<0) return false;
        p.px=lerp(_oldx,p.px,contact.time); p.py=lerp(_oldy,p.py,contact.time);
        p.visual_y=0; mode="lost"; loss_time=0; hit_obstacle=contact.index; drag=undefined;
        return true;
    };
    // Slot captions sit in the strip below the sticker stacks.
    labels=[load_art("ui/title_ground.png"),load_art("ui/title_hook.png"),load_art("ui/title_bounce.png")];
    shuffle=function(_kind,_previous) {
        var _bag=[];
        for (var _i=0;_i<counts[_kind];_i++) array_push(_bag,_i);
        for (var _i=array_length(_bag)-1;_i>0;_i--) {
            var _j=irandom(_i), _temp=_bag[_i]; _bag[_i]=_bag[_j]; _bag[_j]=_temp;
        }
        if (_bag[0]==_previous && array_length(_bag)>1) { var _temp=_bag[0]; _bag[0]=_bag[1]; _bag[1]=_temp; }
        return _bag;
    };
    advance_bag=function(_kind) {
        var _last=bags[_kind][heads[_kind]]; heads[_kind]++;
        if (heads[_kind]>=counts[_kind]) {
            bags[_kind]=next_bags[_kind]; heads[_kind]=0;
            next_bags[_kind]=shuffle(_kind,bags[_kind][counts[_kind]-1]);
        }
    };
    peek=function(_kind,_offset) {
        var _index=heads[_kind]+_offset;
        return _index<counts[_kind]?bags[_kind][_index]:next_bags[_kind][_index-counts[_kind]];
    };
    reset=function() {
        reset_obstacles(); loss_time=0; hit_obstacle=-1;
        random_set_seed(seed); bags=[shuffle(0,-1),shuffle(1,-1),shuffle(2,-1)]; heads=[0,0,0]; stickers=[];
        next_bags=[shuffle(0,bags[0][7]),shuffle(1,bags[1][4]),shuffle(2,bags[2][2])];
        camera_x=0;
        // Feet reference and one stable collision body for every paper pose.
        player={px:100,py:ground_y,vx:run_speed,vy:0,state:"run",grounded:true,hook:-1,last_hook:-1,hook_lock:0,angle:0,omega:0,rope:140,land:0,support:-1,visual_y:0};
        mode="ready"; drag=undefined; placed=0; accumulator=0; clock_time=0;
    };
    art_size=function(_kind,_variant) {
        var _a=assets[_kind][_variant], _scale=min(sizes[_kind][0]/_a.w,sizes[_kind][1]/_a.h);
        if (_kind==0) _scale=max(_scale,200/_a.w);
        return [_a.w*_scale,_a.h*_scale];
    };
    make_sticker=function(_kind,_variant,_x,_y) {
        var _sz=art_size(_kind,_variant);
        return {kind:_kind,variant:_variant,px:_x,py:_y,w:_sz[0],h:_sz[1],top:_y-_sz[1]/2,pulse:0.25,armed:true,tilt:sin(_x*0.13+_variant*2)*1.5};
    };
    surface_of=function(_s,_index) {
        var half=_s.kind==0?_s.w*ground_widths[_s.variant]+6:_s.w*0.46;
        return {left:_s.px-half,right:_s.px+half,top:_s.top+5,index:_index,kind:_s.kind};
    };
    surfaces=function() {
        var list=[{left:24,right:start_right,top:ground_y,index:-1,kind:0},
                  {left:goal_left,right:level_width-24,top:ground_y,index:-3,kind:0}];
        for(var i=0;i<array_length(stickers);i++) if(stickers[i].kind!=1) array_push(list,surface_of(stickers[i],i));
        return list;
    };
    snap_ground=function(_s,_free) {
        if(_s.kind!=0 || _free) return _s;
        var surface=surface_of(_s,-2), list=surfaces(), best=1000000, dx_best=0, dy_best=0;
        for(var i=0;i<array_length(list);i++) {
            var target=list[i];
            if(target.kind!=0) continue;
            var gap=max(target.left-surface.right,surface.left-target.right,0);
            var dy=target.top-surface.top;
            if(gap>snap_range || abs(dy)>snap_range) continue;
            // Deep overlaps are deliberate stacking: do not flatten a small stair.
            var overlap=min(target.right,surface.right)-max(target.left,surface.left);
            if(overlap>40 && abs(dy)>8) continue;
            var dx=0;
            if(abs(surface.left-target.right)<=snap_range) dx=target.right-surface.left-2;
            else if(abs(surface.right-target.left)<=snap_range) dx=target.left-surface.right+2;
            var snap_score=abs(dy)+abs(dx)*0.5;
            if(snap_score<best) { best=snap_score; dx_best=dx; dy_best=dy; }
        }
        _s.px+=dx_best; _s.py+=dy_best; _s.top+=dy_best;
        return _s;
    };
    valid_place=function(_s) {
        var p=player;
        if(_s.kind==0) {
            var surface=surface_of(_s,-2);
            // Only the useful support must fit. Paper decoration may hang below the library.
            if(surface.left<0 || surface.right>level_width || surface.top<body_height+8 || surface.top>play_height-16) return false;
            var touching=surface.right>p.px-body_half && surface.left<p.px+body_half;
            if(touching && surface.top>p.py-body_height && surface.top<p.py+3) {
                var rise=p.py-surface.top;
                var safe_ground=p.grounded && rise<=step_up;
                var safe_catch=p.state!="swing" && !p.grounded && p.vy>=0 && p.vy<=180 && abs(rise)<=12;
                if(!safe_ground && !safe_catch) return false;
            }
            return true;
        }
        // Springs and hooks keep their own interaction rules.
        if(_s.px-_s.w/2<8 || _s.px+_s.w/2>level_width-8 || _s.top<24 || _s.py+_s.h/2>play_height-12) return false;
        if(_s.kind==2 && abs(_s.px-p.px)<_s.w/2+body_half && _s.top>p.py-body_height && _s.top<p.py+3) return false;
        if(_s.kind==1 && point_distance(_s.px,_s.py,p.px,p.py-grab_height)<50) return false;
        if(point_distance(_s.px,_s.py,goal_x,ground_y-85)<95) return false;
        return true;
    };
    settle=function(_surface) {
        var p=player, old_y=p.py;
        p.py=_surface.top; p.vy=0; p.vx=run_speed; p.grounded=true;
        p.state="run"; p.support=_surface.index; p.land=0.12;
        // Collision is resolved immediately; drawing eases the small step.
        p.visual_y=clamp(p.visual_y+old_y-p.py,-step_down,step_up);
    };
    commit_sticker=function(_s) {
        if(mode!="playing" || !valid_place(_s)) return false;
        var index=array_length(stickers);
        array_push(stickers,_s); advance_bag(_s.kind); placed++;
        if(_s.kind==0) {
            var surf=surface_of(_s,index), p=player, rise=p.py-surf.top;
            var overlaps=p.px+foot_half>surf.left && p.px-foot_half<surf.right;
            var grounded_step=p.grounded && rise>=0 && rise<=step_up;
            var slow_catch=!p.grounded && p.state!="swing" && p.vy>=0 && p.vy<=180 && rise>=0 && rise<=12;
            if(overlaps && (grounded_step || slow_catch)) {
                var oldx=p.px, oldy=p.py;
                settle(surf); check_obstacles(oldx,oldy);
            }
        }
        return true;
    };
    start=function() {
        if (mode!="ready") return false;
        mode="playing"; return true;
    };
    update_camera=function() {
        // Forward-only horizontal camera leaves two thirds of the view for planning.
        camera_x=clamp(max(camera_x,player.px-follow_x),0,level_width-width);
    };
    begin_drag=function(_kind,_mx,_my) {
        if (mode!="playing" || !is_undefined(drag)) return false;
        var _variant=peek(_kind,0), _sz=art_size(_kind,_variant), _scale=min(deck_w/_sz[0],deck_h/_sz[1]);
        drag={kind:_kind,variant:_variant,ox:(_mx-slots[_kind])/_scale,oy:(_my-library_y)/_scale};
        return true;
    };
    preview=function(_x,_y) {
        return snap_ground(make_sticker(drag.kind,drag.variant,_x+camera_x-drag.ox,_y-drag.oy),keyboard_check(vk_shift));
    };
    finish_drag=function(_x,_y) {
        if (is_undefined(drag)) return false;
        var _s=preview(_x,_y);
        var _ok=mode=="playing" && _y<play_height && _x>=0 && _x<=width && valid_place(_s);
        if (_ok) _ok=commit_sticker(_s);
        drag=undefined; return _ok;
    };
    release_hook=function() {
        var _p=player;
        if (_p.state!="swing") return false;
        var _vx=_p.rope*_p.omega*cos(_p.angle);
        if (_vx<=0) return false;
        _p.vx=_vx; _p.vy=-_p.rope*_p.omega*sin(_p.angle);
        _p.last_hook=_p.hook; _p.hook=-1; _p.grounded=false; _p.state=_p.vy<0?"rise":"fall";
        return true;
    };
    physics=function(_dt) {
        if(mode!="playing") return;
        var sweep_x=player.px, sweep_y=player.py;
        var _p=player; _p.land=max(0,_p.land-_dt);
        _p.visual_y*=max(0,1-_dt*20);
        if (_p.state=="swing") {
            var _anchor=stickers[_p.hook];
            _p.omega+=-gravity/_p.rope*sin(_p.angle)*_dt; _p.omega*=power(0.999,_dt*60); _p.angle+=_p.omega*_dt;
            _p.px=_anchor.px+sin(_p.angle)*_p.rope; _p.py=_anchor.py+cos(_p.angle)*_p.rope+grab_height;
            if (_p.angle>=release_angle && _p.omega>0) release_hook();
        } else {
            var _oldx=_p.px, _oldy=_p.py, _was_grounded=_p.grounded;
            _p.vy+=gravity*_dt; _p.px+=_p.vx*_dt; _p.py+=_p.vy*_dt; _p.grounded=false;
            var _hit=-2, _hit_y=1000000, _surfaces=surfaces(), _current=undefined;
            for(var i=0;i<array_length(_surfaces);i++) {
                var surf=_surfaces[i];
                if(surf.index==_p.support && abs(surf.top-_oldy)<0.5) _current=surf;
            }
            // Walking support and falling interception are intentionally separate.
            if(_was_grounded && !is_undefined(_current)) {
                var up=undefined, base=undefined, down=undefined;
                for(var i=0;i<array_length(_surfaces);i++) {
                    var surf=_surfaces[i], delta=surf.top-_oldy;
                    var overlaps=_p.px+foot_half>surf.left && _p.px-foot_half<surf.right;
                    if(!overlaps) continue;
                    // Only entering a forward edge may step upwards: stacked layers
                    // cannot pull a stationary runner up one level every simulation tick.
                    var entering=_oldx+foot_half<=surf.left+0.01 && _p.px+foot_half>surf.left;
                    if(delta< -0.5 && delta>=-step_up && entering) {
                        if(is_undefined(up) || surf.top>up.top) up=surf;
                    } else if(abs(delta)<=0.5) {
                        var spring=surf.kind==2 && stickers[surf.index].armed;
                        if(is_undefined(base) || spring || (base.kind!=2 && surf.right>base.right)) base=surf;
                    } else if(delta>0.5 && delta<=step_down) {
                        if(is_undefined(down) || surf.top<down.top) down=surf;
                    }
                }
                var chosen=!is_undefined(up)?up:(!is_undefined(base)?base:down);
                if(!is_undefined(chosen)) { _hit=chosen.index; _hit_y=chosen.top; }
                else {
                    // Keep support only over a genuinely small gap with a real landing.
                    // The geometric distance is measured between edges, not from the body.
                    for(var i=0;i<array_length(_surfaces);i++) {
                        var surf=_surfaces[i], gap=surf.left-_current.right;
                        if(gap>0 && gap<=small_gap && surf.top==_current.top
                           && _p.px>=_current.right-foot_half && _p.px<surf.left
                           && surf.right>_p.px) {
                            _hit=_current.index; _hit_y=_current.top; break;
                        }
                    }
                }
            }
            if(_hit==-2 && _p.vy>=0) {
                for(var i=0;i<array_length(_surfaces);i++) {
                    var surf=_surfaces[i];
                    if(_oldy<=surf.top+0.01 && _p.py>=surf.top) {
                        var ratio=clamp((surf.top-_oldy)/max(0.0001,_p.py-_oldy),0,1), crossx=lerp(_oldx,_p.px,ratio);
                        var spring=surf.kind==2 && stickers[surf.index].armed && abs(surf.top-_hit_y)<0.1;
                        // A runner that has just left an edge must not repeatedly
                        // regain support from its trailing body overhang.
                        var half=_was_grounded?foot_half:body_half;
                        if(crossx+half>surf.left && crossx-half<surf.right && (surf.top<_hit_y || spring)) {
                            _hit=surf.index; _hit_y=surf.top;
                        }
                    }
                }
            }
            if(_hit!=-2) {
                if(_hit>=0 && stickers[_hit].kind==2 && stickers[_hit].armed) {
                    _p.py=_hit_y; _p.support=-2;
                    _p.vy=-sqrt(2*gravity*max(24,_hit_y/2)); stickers[_hit].armed=false; stickers[_hit].pulse=0.45; _p.state="rise";
                } else {
                    if(_was_grounded && abs(_hit_y-_oldy)>0.5) _p.visual_y=clamp(_p.visual_y+_oldy-_hit_y,-step_down,step_up);
                    _p.py=_hit_y; _p.vy=0; _p.vx=run_speed; _p.grounded=true; _p.support=_hit; _p.state="run";
                    if(!_was_grounded || abs(_hit_y-_oldy)>0.5) _p.land=0.12;
                }
            } else { _p.support=-2; _p.state=_p.vy<0?"rise":"fall"; }
            // A grounded runner can also be caught; a spring wins its launch frame.
            if (!(_hit>=0 && stickers[_hit].kind==2 && _p.state=="rise")) {
                for (var _i=0;_i<array_length(stickers);_i++) {
                    var _s=stickers[_i];
                    if (_s.kind!=1 || _i==_p.last_hook) continue;
                    var _dx=_p.px-_s.px, _dy=(_p.py-grab_height)-_s.py, _distance=sqrt(_dx*_dx+_dy*_dy);
                    if (_distance>=72 && _distance<=hook_radius && _dy>38 && _dx< -8) {
                        _p.hook=_i; _p.rope=_distance; _p.angle=arctan2(_dx,_dy);
                        // Give a slow arrival enough energy for one complete forward transfer.
                        // E/m = .5*(L*w)^2 + g*L*(1-cos(angle)).
                        var _incoming=(_p.vx*cos(_p.angle)-_p.vy*sin(_p.angle))/_distance;
                        var _minimum=sqrt(max(0,2*gravity/_distance*(cos(_p.angle)-cos(degtorad(72)))));
                        _p.omega=max(0.8,_minimum,_incoming);
                        _p.state="swing"; _p.grounded=false; _s.pulse=0.4; break;
                    }
                }
            }
        }
        for (var _i=0;_i<array_length(stickers);_i++) {
            var _s=stickers[_i]; _s.pulse=max(0,_s.pulse-_dt);
            if (_s.kind==2 && !_s.armed && (abs(_p.py-(_s.top+5))>20 || abs(_p.px-_s.px)>_s.w/2+12)) _s.armed=true;
        }
        if (_p.last_hook>=0) {
            var _last=stickers[_p.last_hook];
            if (point_distance(_last.px,_last.py,_p.px,_p.py-grab_height)>hook_radius+24) _p.last_hook=-1;
        }
        if(check_obstacles(sweep_x,sweep_y)) { update_camera(); return; }
        update_camera();
        if (_p.py>play_height || _p.px< -24 || _p.px>level_width+24) { mode="lost"; drag=undefined; }
        if (_p.grounded && _p.px>=goal_x-28 && abs(_p.py-ground_y)<2) { mode="won"; drag=undefined; }
    };
    update=function() {
        var _dt=min(delta_time/1000000,0.05);
        if (mode=="playing") clock_time+=_dt*play_pace;
        if (mode=="lost" && hit_obstacle>=0) loss_time=min(1,loss_time+_dt);
        mx=device_mouse_x_to_gui(0); my=device_mouse_y_to_gui(0);
        if (keyboard_check_pressed(ord("R"))) { reset(); return; }
        if (keyboard_check_pressed(vk_escape) || keyboard_check_pressed(ord("P"))) {
            if (mode=="playing") { mode="paused"; drag=undefined; } else if (mode=="paused") mode="playing";
        }
        if (mouse_check_button_pressed(mb_right)) drag=undefined;
        var _press=mouse_check_button_pressed(mb_left);
        if (mode=="ready") {
            if ((_press && point_in_rectangle(mx,my,210,205,380,274)) || keyboard_check_pressed(vk_enter)) start();
            _press=false; // A begin click can never pick up a sticker.
        } else if (mode=="lost" || mode=="won") {
            if ((_press && point_distance(mx,my,width/2,260)<46) || keyboard_check_pressed(vk_enter)) reset();
            _press=false;
        } else if (mode=="paused") {
            if ((_press && point_distance(mx,my,width/2,260)<46) || keyboard_check_pressed(vk_enter)) mode="playing";
            _press=false;
        } else if ((_press && point_distance(mx,my,width-45,42)<26) || keyboard_check_pressed(vk_enter)) {
            mode="paused"; drag=undefined; _press=false;
        }
        if (mode=="playing") {
            if (_press && is_undefined(drag)) for (var _i=0;_i<3;_i++) {
                if (point_in_rectangle(mx,my,slots[_i]-145,play_height+12,slots[_i]+145,758)) { begin_drag(_i,mx,my); break; }
            }
            if (mouse_check_button_released(mb_left) && !is_undefined(drag)) finish_drag(mx,my);
            accumulator+=_dt*play_pace;
            repeat (12) { if (accumulator<1/120 || mode!="playing") break; physics(1/120); accumulator-=1/120; }
        } else accumulator=0;
    };
    draw_art=function(_a,_x,_y,_w,_h,_alpha,_tint,_angle) {
        if (_a.sprite<0) return;
        var _sx=_w/_a.w, _sy=_h/_a.h, _cx=(_a.left+_a.w/2)*_sx, _cy=(_a.top+_a.h/2)*_sy;
        var _c=dcos(_angle), _sn=dsin(_angle);
        draw_sprite_ext(_a.sprite,0,_x-_cx*_c-_cy*_sn,_y+_cx*_sn-_cy*_c,_sx,_sy,_angle,_tint,_alpha);
    };
    draw_sticker=function(_s,_preview,_valid) {
        var _x=_s.px-camera_x, _tint=_preview && !_valid?make_color_rgb(255,115,105):c_white;
        var _squash=_preview?1:1-sin(_s.pulse*25)*_s.pulse*0.18;
        draw_art(assets[_s.kind][_s.variant],_x,_s.py,_s.w/_squash,_s.h*_squash,_preview?0.8:1,_tint,_preview?-3:_s.tilt);
        if (_preview) {
            draw_set_color(_valid?ink:make_color_rgb(245,110,100)); draw_set_alpha(0.55);
            if (_s.kind==1) {
                // Only the useful lower-left capture region, followed by a forward arc.
                for (var j=0;j<10;j++) {
                    var a=degtorad(-65+j*6);
                    draw_circle(_x+sin(a)*hook_radius,_s.py+cos(a)*hook_radius,1.8,false);
                }
                draw_line(_x+30,_s.py+130,_x+85,_s.py+100);
                draw_line(_x+85,_s.py+100,_x+70,_s.py+99);
            } else {
                var surf=surface_of(_s,-2);
                draw_line_width(surf.left-camera_x,surf.top,surf.right-camera_x,surf.top,2);
            }
            draw_set_alpha(1);
        }
    };
    paper_limb=function(_x1,_y1,_x2,_y2,_weight) {
        var dx=_x2-_x1, dy=_y2-_y1, len=max(1,sqrt(dx*dx+dy*dy));
        var nx=-dy/len*_weight/2, ny=dx/len*_weight/2;
        draw_triangle(_x1+nx,_y1+ny,_x1-nx,_y1-ny,_x2+nx*0.65,_y2+ny*0.65,false);
        draw_triangle(_x1-nx,_y1-ny,_x2-nx*0.8,_y2-ny*0.8,_x2+nx*0.65,_y2+ny*0.65,false);
    };
    draw_player=function() {
        var p=player, xx=p.px-camera_x, feet=min(p.py+p.visual_y,play_height-8), hip=feet-27, shoulder=feet-51;
        var stride=p.state=="run" && mode=="playing"?sin(floor(clock_time*7)/7*10)*15:4;
        if (p.land>0) { shoulder+=7; hip+=4; }
        if (mode=="won") draw_set_alpha(0.65+0.35*cos(clock_time*3));
        if (mode=="lost" && hit_obstacle>=0) draw_set_alpha(1-clamp((loss_time-0.16)/0.34,0,1));
        draw_set_color(ink);
        // Uneven cut-paper torso and head, with stepped gait rather than smooth sticks.
        draw_triangle(xx-10,shoulder,xx+9,shoulder-2,xx+13,hip+3,false);
        draw_triangle(xx-10,shoulder,xx+13,hip+3,xx-9,hip+1,false);
        draw_triangle(xx-9,shoulder-17,xx+8,shoulder-20,xx+12,shoulder-6,false);
        draw_triangle(xx-9,shoulder-17,xx+12,shoulder-6,xx-6,shoulder-3,false);
        if (p.state=="run") {
            paper_limb(xx-5,hip,xx-stride,feet-2,10); paper_limb(xx+5,hip,xx+stride,feet,11);
            paper_limb(xx-9,shoulder+4,xx-18,shoulder+22+stride*0.3,8);
            paper_limb(xx+8,shoulder+3,xx+18,shoulder+22-stride*0.3,7);
        } else {
            var arms=p.state=="swing"?-16:(p.state=="rise"?-8:12);
            paper_limb(xx-8,shoulder+3,xx-18,shoulder+arms,8);
            paper_limb(xx+8,shoulder+3,xx+16,shoulder+arms,8);
            paper_limb(xx-5,hip,xx-15,feet-8,11); paper_limb(xx+5,hip,xx+13,feet-12,10);
        }
        draw_set_color(make_color_rgb(46,43,39)); draw_line_width(xx+5,shoulder-14,xx+7,shoulder-12,2);
        draw_set_alpha(1);
    };
    draw_ledge=function(_left,_right) {
        var l=_left-camera_x, r=_right-camera_x;
        if(r<0 || l>width) return;
        draw_set_color(ink);
        draw_primitive_begin(pr_trianglefan);
        draw_vertex(l,ground_y); draw_vertex(r,ground_y); draw_vertex(r-4,ground_y+9);
        draw_vertex(r-34,ground_y+7); draw_vertex((l+r)/2+19,ground_y+12);
        draw_vertex(l+43,ground_y+8); draw_vertex(l+2,ground_y+11);
        draw_primitive_end();
    };
    draw_retry=function(_x,_y) {
        draw_set_color(ink);
        for(var j=0;j<19;j++) {
            var a=40+j*14, b=a+14;
            draw_line_width(_x+dcos(a)*24,_y-dsin(a)*24,_x+dcos(b)*24,_y-dsin(b)*24,4);
        }
        draw_triangle(_x+24,_y-22,_x+8,_y-18,_x+24,_y-8,false);
    };
    draw=function() {
        draw_clear(c_black);
        draw_ledge(24,start_right); draw_ledge(goal_left,level_width-24);
        if(goal_x-camera_x<width+100) draw_art(destination,goal_x-camera_x,ground_y-86,124,168,1,c_white,-3);
        for(var i=0;i<array_length(stickers);i++) {
            var s=stickers[i]; if(s.px+s.w/2>=camera_x && s.px-s.w/2<=camera_x+width) draw_sticker(s,false,true);
        }
        if(player.state=="swing") {
            var s=stickers[player.hook];
            draw_set_color(ink);
            draw_line_width(s.px-camera_x,s.py,player.px-camera_x,player.py-grab_height,2);
            draw_circle(s.px-camera_x,s.py,4,true);
        }
        draw_player();
        if(!is_undefined(drag) && my<play_height) { var s=preview(mx,my); draw_sticker(s,true,valid_place(s)); }
        // Draw above placed AND dragged stickers so danger cannot be hidden by paper.
        for(var i=0;i<array_length(obstacles);i++) {
            var o=obstacles[i], xx=o.px-camera_x;
            if(xx+o.w/2<0 || xx-o.w/2>width) continue;
            var phase=floor(clock_time*7)/7+i*1.7;
            draw_art(obstacle_art[o.variant],xx,o.py,o.w,o.h,
                     0.93+0.07*sin(phase*1.4),c_white,sin(phase)*1.2);
        }
        draw_set_color(c_black); draw_rectangle(0,play_height,width,768,false);
        draw_set_color(make_color_rgb(53,50,46));
        for(var i=0;i<40;i++) {
            var xx=18+i*33.2;
            draw_line(xx,play_height+sin(i*2.3)*1.2,xx+31,play_height+sin((i+1)*2.3)*1.2);
        }
        for(var k=0;k<3;k++) {
            var lifted=!is_undefined(drag) && drag.kind==k;
            var hover=mode=="playing" && is_undefined(drag) && point_in_rectangle(mx,my,slots[k]-145,590,slots[k]+145,758);
            for(var deck_depth=2;deck_depth>=0;deck_depth--) {
                var variant=peek(k,deck_depth+(lifted?1:0));
                var sz=art_size(k,variant), scale=min(deck_w/sz[0],deck_h/sz[1]);
                var offset=deck_depth==0?0:(deck_depth==1?-19:17);
                var tilt=deck_depth==0?-2+k*2:(deck_depth==1?7:-8);
                draw_art(assets[k][variant],slots[k]+offset,library_y+deck_depth*2-(hover&&deck_depth==0?4:0),
                    sz[0]*scale,sz[1]*scale,deck_depth==0?1:0.65,c_white,tilt);
            }
        }
        for(var k=0;k<3;k++) {
            var label=labels[k], label_scale=label_h/max(1,label.h);
            draw_art(label,slots[k],label_y,label.w*label_scale,label.h*label_scale,1,c_white,0);
        }
        if(!is_undefined(drag) && my>=play_height) {
            var sz=art_size(drag.kind,drag.variant), scale=min(deck_w/sz[0],deck_h/sz[1]);
            draw_art(assets[drag.kind][drag.variant],mx-drag.ox*scale,my-drag.oy*scale,sz[0]*scale,sz[1]*scale,1,c_white,-5);
        }
        if(mode=="ready") {
            draw_set_color(ink);
            draw_triangle(214,215,378,208,372,267,false); draw_triangle(214,215,372,267,218,273,false);
            draw_set_font(font_title); draw_set_color(c_black); draw_set_halign(fa_center); draw_set_valign(fa_middle);
            draw_text_transformed(295,239,"begin",1,1,3);
        } else if(mode=="playing") {
            draw_set_color(muted); paper_limb(width-51,31,width-52,52,4); paper_limb(width-39,31,width-40,52,4);
        } else {
            draw_set_alpha(0.5); draw_set_color(c_black); draw_rectangle(width/2-55,205,width/2+55,315,false); draw_set_alpha(1);
            if(mode=="paused") { draw_set_color(ink); draw_triangle(width/2-13,237,width/2-13,283,width/2+23,260,false); }
            else draw_retry(width/2,260);
        }
        draw_set_alpha(1); draw_set_color(c_white); draw_set_halign(fa_left); draw_set_valign(fa_top); draw_set_font(-1);
    };
    cleanup=function() {
        for (var _i=0;_i<array_length(all_sprites);_i++) if (sprite_exists(all_sprites[_i])) sprite_delete(all_sprites[_i]);
        font_delete(font_title);
    };
    reset();
}

