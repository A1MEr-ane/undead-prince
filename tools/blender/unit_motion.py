"""Common 12 fps poses for the recipe rig. Positions are fractions of rider height."""
import math

from build_swordsman import blend

POSES = {
    'attack': [
        (0, {}),
        (.28, dict(hip=(-.055, 0, .31), lean=-13, head_tilt=9,
                   wrist_r=(-.20, .19, .68), sword=-54,
                   wrist_l=(.12, -.24, .41), shield=40)),
        (.50, dict(hip=(.065, 0, .31), lean=23, head_tilt=-12,
                   wrist_r=(.32, .14, .57), sword=90,
                   wrist_l=(-.055, -.24, .38), shield=-35,
                   foot_l=(.14, -.08, .0605), foot_r=(-.09, .08, .0605))),
        (.74, dict(hip=(.052, 0, .29), lean=27, head_tilt=-18,
                   wrist_r=(.27, .15, .27), sword=145,
                   wrist_l=(-.14, -.22, .37), shield=-48,
                   foot_l=(.13, -.08, .0605), foot_r=(-.09, .08, .0605))),
        (1, {}),
    ],
    'parry': [
        (0, {}),
        (.19, dict(hip=(-.046, 0, .30), lean=-10, head_tilt=-7,
                   wrist_l=(.09, -.22, .39), wrist_r=(.13, .19, .45), sword=24)),
        (.375, dict(hip=(.04, 0, .29), lean=12, head_tilt=-8,
                    wrist_l=(.285, -.21, .51), shield=-18,
                    wrist_r=(.19, .19, .43), sword=13,
                    foot_l=(.12, -.08, .0605), foot_r=(-.09, .08, .0605))),
        (.62, dict(hip=(.02, 0, .28), lean=5,
                   wrist_l=(.21, -.22, .42), wrist_r=(.21, .19, .34), sword=42)),
        (1, {}),
    ],
    'hit_light': [
        (0, dict(lean=-8, head_tilt=-20)),
        (.33, dict(lean=-13, head_tilt=-22)),
        (.66, dict(head_tilt=-7)),
        (1, {}),
    ],
    'hit_heavy': [
        (0, {}),
        (1 / 7, dict(hip=(-.07, 0, .30), lean=-39, head_tilt=-18,
                     wrist_r=(.20, .19, .52), wrist_l=(.18, -.22, .56),
                     sword=45, shield=62)),
        (.5, dict(hip=(-.19, 0, .27), lean=-32, head_tilt=12,
                  foot_l=(.018, -.08, .078), foot_r=(-.27, .08, .0605),
                  wrist_r=(.10, .24, .39), wrist_l=(.07, -.24, .40))),
        (.8, dict(hip=(-.105, 0, .29), lean=-12, foot_r=(-.18, .08, .0605))),
        (1, {}),
    ],
    'knockback': [
        (0, {}),
        (1 / 6, dict(hip=(-.08, 0, .42), lean=-28, head_tilt=-15,
                      foot_l=(.09, -.08, .208), foot_r=(-.16, .08, .18),
                      wrist_l=(.139, -.24, .585), wrist_r=(-.29, .22, .61),
                      sword=-80, shield=74)),
        (.56, dict(hip=(-.15, 0, .43), lean=-19, head_tilt=-8,
                   foot_l=(.02, -.08, .21), foot_r=(-.216, .08, .185),
                   wrist_l=(.09, -.24, .61), wrist_r=(-.32, .22, .60),
                   sword=-69, shield=64)),
        (1, dict(hip=(-.09, 0, .27), lean=-18, head_tilt=12,
                 foot_l=(.05, -.08, .0605), foot_r=(-.20, .08, .0605),
                 wrist_l=(.22, -.24, .32), wrist_r=(-.17, .22, .42), sword=-32)),
    ],
    'hit_arrow': [
        (0, {}),
        (1 / 6, dict(hip=(.05, 0, .30), lean=29, head_tilt=14,
                      wrist_l=(.15, -.16, .49), shield=-40,
                      wrist_r=(.22, .21, .26), sword=126)),
        (.59, dict(hip=(.052, 0, .28), lean=34, head_tilt=21,
                   wrist_l=(.15, -.16, .46), shield=-44,
                   wrist_r=(.17, .22, .23), sword=142)),
        (1, {}),
    ],
    'death_pierce': [
        (0, {}),
        (.25, dict(hip=(.04, 0, .23), lean=32, head_tilt=20,
                   wrist_l=(.15, -.19, .42), wrist_r=(.18, .22, .17), sword=135)),
        (5 / 7, dict(hip=(-.028, 0, .155), lean=34, head_tilt=31,
                     foot_l=(.14, -.08, .0605), foot_r=(-.22, .08, .068),
                     wrist_l=(.10, -.18, .32), wrist_r=(.27, .20, .085),
                     sword=117, shield=-25)),
        (1, dict(hip=(-.037, 0, .155), lean=37, head_tilt=35,
                 foot_l=(.14, -.08, .0605), foot_r=(-.22, .08, .068),
                 wrist_l=(.12, -.18, .30), wrist_r=(.27, .20, .085),
                 sword=117, shield=-25)),
    ],
    'death_crush': [
        (0, {}),
        (.16, dict(hip=(0, 0, .29), head_tilt=-24,
                   wrist_l=(-.16, -.21, .63), wrist_r=(.21, .22, .67),
                   sword=9, shield=-35)),
        (4 / 6, dict(hip=(-.05, 0, .18), lean=64, head_tilt=22,
                     foot_l=(-.07, -.08, .0605), foot_r=(-.21, .08, .0605),
                     wrist_l=(.58, -.19, .16), wrist_r=(-.23, .22, .14),
                     sword=-92, shield=46, vertical_scale=.29)),
        (1, dict(hip=(-.05, 0, .18), lean=69, head_tilt=20,
                 foot_l=(-.07, -.08, .0605), foot_r=(-.21, .08, .0605),
                 wrist_l=(.58, -.19, .15), wrist_r=(-.23, .22, .14),
                 sword=-92, shield=46, vertical_scale=.26)),
    ],
}


def shuffle(unit, phase):
    pose = dict(unit.neutral)
    # At each step event the named foot leads and both soles are down.
    # Each foot lifts only on the intervening sample before its own landing.
    stride = .077 * unit.height
    swing = math.cos(math.tau * phase)
    for side, sign in (('r', 1), ('l', -1)):
        x, y, _ = pose[f'foot_{side}']
        lift = max(0, -sign * math.sin(math.tau * phase)) * .009 * unit.height
        pose[f'foot_{side}'] = (x * .28 + stride * sign * swing, y, unit.ankle_z + lift)
    return pose


def posed(unit, name, phase):
    neutral = dict(unit.neutral, vertical_scale=1.)
    if name == 'stun':
        sway = math.sin(math.tau * phase)
        neutral.update(lean=neutral['lean'] + 22 * sway, head_tilt=-27 * sway - 8,
                       hip=unit.control_value('hip', (.023 * sway, 0, .30)),
                       wrist_l=unit.control_value('wrist_l', (-.10 + .04 * sway, -.21, .29)),
                       wrist_r=unit.control_value('wrist_r', (.14 + .05 * sway, .22, .27)),
                       sword=142 + 12 * sway, shield=-40)
        return neutral
    return blend([(at, neutral | {key: unit.control_value(key, value) for key, value in values.items()})
                  for at, values in POSES[name]], phase)
